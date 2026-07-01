```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract CraftableERC1155 is ERC1155, ERC1155Supply, AccessControl, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;
    using Strings for uint256;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant CRAFTER_ROLE = keccak256("CRAFTER_ROLE");
    bytes32 public constant MARKETPLACE_ROLE = keccak256("MARKETPLACE_ROLE");

    struct Recipe {
        uint256[] requiredTokenIds;
        uint256[] requiredAmounts;
        uint256 resultTokenId;
        uint256 resultAmount;
        bool active;
    }

    struct MarketplaceListing {
        address seller;
        uint256 tokenId;
        uint256 amount;
        uint256 pricePerToken;
        address paymentToken; // address(0) for ETH
        bool active;
        uint256 expirationBlock;
    }

    mapping(uint256 => Recipe) public recipes;
    mapping(uint256 => string) private _tokenURIs;
    mapping(uint256 => MarketplaceListing) public marketplaceListings;
    mapping(address => mapping(uint256 => bool)) public approvedMarketplaces;
    
    uint256 public nextRecipeId;
    uint256 public nextListingId;
    uint256 public marketplaceFee; // basis points (e.g., 250 = 2.5%)
    address public feeRecipient;
    string private _baseTokenURI;

    event RecipeCreated(uint256 indexed recipeId, uint256[] requiredTokenIds, uint256[] requiredAmounts, uint256 resultTokenId, uint256 resultAmount);
    event TokenCrafted(address indexed crafter, uint256 indexed recipeId, uint256 resultTokenId, uint256 resultAmount);
    event MarketplaceListed(uint256 indexed listingId, address indexed seller, uint256 indexed tokenId, uint256 amount, uint256 pricePerToken, address paymentToken);
    event MarketplaceSale(uint256 indexed listingId, address indexed buyer, address indexed seller, uint256 tokenId, uint256 amount, uint256 totalPrice);
    event ListingCancelled(uint256 indexed listingId);
    event MetadataUpdated(uint256 indexed tokenId, string newURI);

    modifier validAddress(address _addr) {
        require(_addr != address(0), "Invalid address");
        _;
    }

    modifier validTokenId(uint256 _tokenId) {
        require(_tokenId > 0, "Invalid token ID");
        _;
    }

    modifier validAmount(uint256 _amount) {
        require(_amount > 0, "Invalid amount");
        _;
    }

    modifier listingExists(uint256 _listingId) {
        require(_listingId < nextListingId, "Listing does not exist");
        require(marketplaceListings[_listingId].active, "Listing not active");
        _;
    }

    modifier recipeExists(uint256 _recipeId) {
        require(_recipeId < nextRecipeId, "Recipe does not exist");
        require(recipes[_recipeId].active, "Recipe not active");
        _;
    }

    constructor(
        string memory _uri,
        address _feeRecipient,
        uint256 _marketplaceFee
    ) ERC1155(_uri) validAddress(_feeRecipient) {
        require(_marketplaceFee <= 1000, "Fee too high"); // Max 10%
        
        _baseTokenURI = _uri;
        feeRecipient = _feeRecipient;
        marketplaceFee = _marketplaceFee;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(CRAFTER_ROLE, msg.sender);
    }

    function mint(
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) external onlyRole(MINTER_ROLE) validAddress(to) validTokenId(id) validAmount(amount) whenNotPaused {
        _mint(to, id, amount, data);
    }

    function mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) external onlyRole(MINTER_ROLE) validAddress(to) whenNotPaused {
        require(ids.length == amounts.length, "Arrays length mismatch");
        require(ids.length > 0, "Empty arrays");
        
        for (uint256 i = 0; i < ids.length; i++) {
            require(ids[i] > 0, "Invalid token ID");
            require(amounts[i] > 0, "Invalid amount");
        }
        
        _mintBatch(to, ids, amounts, data);
    }

    function createRecipe(
        uint256[] calldata requiredTokenIds,
        uint256[] calldata requiredAmounts,
        uint256 resultTokenId,
        uint256 resultAmount
    ) external onlyRole(CRAFTER_ROLE) validTokenId(resultTokenId) validAmount(resultAmount) {
        require(requiredTokenIds.length == requiredAmounts.length, "Arrays length mismatch");
        require(requiredTokenIds.length > 0, "Empty requirements");
        
        for (uint256 i = 0; i < requiredTokenIds.length; i++) {
            require(requiredTokenIds[i] > 0, "Invalid required token ID");
            require(requiredAmounts[i] > 0, "Invalid required amount");
        }

        uint256 recipeId = nextRecipeId++;
        
        recipes[recipeId] = Recipe({
            requiredTokenIds: requiredTokenIds,
            requiredAmounts: requiredAmounts,
            resultTokenId: resultTokenId,
            resultAmount: resultAmount,
            active: true
        });

        emit RecipeCreated(recipeId, requiredTokenIds, requiredAmounts, resultTokenId, resultAmount);
    }

    function craft(uint256 recipeId) external nonReentrant recipeExists(recipeId) whenNotPaused {
        Recipe storage recipe = recipes[recipeId];
        
        // Check balances first
        for (uint256 i = 0; i < recipe.requiredTokenIds.length; i++) {
            require(
                balanceOf(msg.sender, recipe.requiredTokenIds[i]) >= recipe.requiredAmounts[i],
                "Insufficient balance for crafting"
            );
        }

        // Burn required tokens
        for (uint256 i = 0; i < recipe.requiredTokenIds.length; i++) {
            _burn(msg.sender, recipe.requiredTokenIds[i], recipe.requiredAmounts[i]);
        }

        // Mint result token
        _mint(msg.sender, recipe.resultTokenId, recipe.resultAmount, "");

        emit TokenCrafted(msg.sender, recipeId, recipe.resultTokenId, recipe.resultAmount);
    }

    function listOnMarketplace(
        uint256 tokenId,
        uint256 amount,
        uint256 pricePerToken,
        address paymentToken,
        uint256 expirationBlocks
    ) external nonReentrant validTokenId(tokenId) validAmount(amount) whenNotPaused {
        require(pricePerToken > 0, "Invalid price");
        require(expirationBlocks > 0, "Invalid expiration");
        require(balanceOf(msg.sender, tokenId) >= amount, "Insufficient balance");
        require(isApprovedForAll(msg.sender, address(this)), "Contract not approved");

        uint256 listingId = nextListingId++;
        uint256 expirationBlock = block.number + expirationBlocks;
        
        marketplaceListings[listingId] = MarketplaceListing({
            seller: msg.sender,
            tokenId: tokenId,
            amount: amount,
            pricePerToken: pricePerToken,
            paymentToken: paymentToken,
            active: true,
            expirationBlock: expirationBlock
        });

        emit MarketplaceListed(listingId, msg.sender, tokenId, amount, pricePerToken, paymentToken);
    }

    function buyFromMarketplace(
        uint256 listingId,
        uint256 amount
    ) external payable nonReentrant listingExists(listingId) validAmount(amount) whenNotPaused {
        MarketplaceListing storage listing = marketplaceListings[listingId];
        
        require(block.number <= listing.expirationBlock, "Listing expired");
        require(msg.sender != listing.seller, "Cannot buy own listing");
        require(amount <= listing.amount, "Insufficient amount available");
        require(balanceOf(listing.seller, listing.tokenId) >= amount, "Seller insufficient balance");

        uint256 totalPrice = listing.pricePerToken * amount;
        uint256 feeAmount = (totalPrice * marketplaceFee) / 10000;
        uint256 sellerAmount = totalPrice - feeAmount;

        // Update listing
        listing.amount -= amount;
        if (listing.amount == 0) {
            listing.active = false;
        }

        // Handle payments
        if (listing.paymentToken == address(0)) {
            // ETH payment
            require(msg.value == totalPrice, "Incorrect ETH amount");
            
            if (feeAmount > 0) {
                (bool feeSuccess, ) = feeRecipient.call{value: feeAmount}("");
                require(feeSuccess, "Fee transfer failed");
            }
            
            (bool sellerSuccess, ) = listing.seller.call{value: sellerAmount}("");
            require(sellerSuccess, "Seller payment failed");
        } else {
            // ERC20 payment
            require(msg.value == 0, "ETH not accepted for ERC20 payments");
            
            IERC20 paymentToken = IERC20(listing.paymentToken);
            
            if (feeAmount > 0) {
                paymentToken.safeTransferFrom(msg.sender, feeRecipient, feeAmount);
            }
            paymentToken.safeTransferFrom(msg.sender, listing.seller, sellerAmount);
        }

        // Transfer tokens
        _safeTransferFrom(listing.seller, msg.sender, listing.tokenId, amount, "");

        emit MarketplaceSale(listingId, msg.sender, listing.seller, listing.tokenId, amount, totalPrice);
    }

    function cancelListing(uint256 listingId) external listingExists(listingId) {
        MarketplaceListing storage listing = marketplaceListings[listingId];
        require(msg.sender == listing.seller, "Not the seller");
        
        listing.active = false;
        
        emit ListingCancelled(listingId);
    }

    function setTokenURI(uint256 tokenId, string calldata tokenURI) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
        validTokenId(tokenId) 
    {
        _tokenURIs[tokenId] = tokenURI;
        emit MetadataUpdated(tokenId, tokenURI);
    }

    function setBaseURI(string calldata newBaseURI) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _baseTokenURI = newBaseURI;
    }

    function setMarketplaceFee(uint256 newFee) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newFee <= 1000, "Fee too high"); // Max 10%
        marketplaceFee = newFee;
    }

    function setFeeRecipient(address newRecipient) external onlyRole(DEFAULT_ADMIN_ROLE) validAddress(newRecipient) {
        feeRecipient = newRecipient;
    }

    function toggleRecipe(uint256 recipeId) external onlyRole(CRAFTER_ROLE) {
        require(recipeId < nextRecipeId, "Recipe does not exist");
        recipes[recipeId].active = !recipes[recipeId].active;
    }

    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    function uri(uint256 tokenId) public view override returns (string memory) {
        if (bytes(_tokenURIs[tokenId]).length > 0) {
            return _tokenURIs[tokenId];
        }
        
        return string(abi.encodePacked(_baseTokenURI, tokenId.toString()));
    }

    function getRecipe(uint256 recipeId) external view returns (Recipe memory) {
        require(recipeId < nextRecipeId, "Recipe does not exist");
        return recipes[recipeId];
    }

    function getListing(uint256 listingId) external view returns (MarketplaceListing memory) {
        require(listingId < nextListingId, "Listing does not exist");
        return marketplaceListings[listingId];
    }

    function isListingActive(uint256 listingId) external view returns (bool) {
        if (listingId >= nextListingId) return false;
        
        MarketplaceListing memory listing = marketplaceListings[listingId];
        return listing.active && block.number <= listing.expirationBlock;
    }

    function emergencyWithdraw() external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 balance = address(this).balance;
        if (balance > 0) {
            (bool success, ) = feeRecipient.call{value: balance}("");
            require(success, "Withdrawal failed");
        }
    }

    function emergencyWithdrawToken(address token) external onlyRole(DEFAULT_ADMIN_ROLE) validAddress(token) {
        IERC20 erc20Token = IERC20(token);
        uint256 balance = erc20Token.balanceOf(address(this));
        if (balance > 0) {
            erc20Token.safeTransfer(feeRecipient, balance);
        }
    }

    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal override(ERC1155, ERC1155Supply) whenNotPaused {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC1155, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    receive() external payable {
        revert("Direct payments not accepted");
    }