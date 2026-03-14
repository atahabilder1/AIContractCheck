// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract CraftableERC1155 is ERC1155, ERC1155Supply, Ownable, ReentrancyGuard {
    using Strings for uint256;

    string public name;
    string public symbol;

    struct CraftingRecipe {
        uint256[] inputTokenIds;
        uint256[] inputAmounts;
        uint256 outputTokenId;
        uint256 outputAmount;
        bool active;
    }

    struct Listing {
        address seller;
        uint256 tokenId;
        uint256 amount;
        uint256 pricePerUnit;
        bool active;
    }

    uint256 private _nextRecipeId;
    uint256 private _nextListingId;

    mapping(uint256 => CraftingRecipe) public recipes;
    mapping(uint256 => Listing) public listings;
    mapping(uint256 => string) private _tokenURIs;
    mapping(uint256 => bool) public tokenExists;

    string private _baseURI;

    uint256 public marketplaceFee = 250; // 2.5%
    uint256 public constant FEE_DENOMINATOR = 10000;
    address public feeRecipient;

    event RecipeCreated(uint256 indexed recipeId, uint256[] inputTokenIds, uint256[] inputAmounts, uint256 outputTokenId, uint256 outputAmount);
    event RecipeToggled(uint256 indexed recipeId, bool active);
    event ItemCrafted(address indexed crafter, uint256 indexed recipeId, uint256 outputTokenId, uint256 outputAmount);
    event Listed(uint256 indexed listingId, address indexed seller, uint256 tokenId, uint256 amount, uint256 pricePerUnit);
    event Sale(uint256 indexed listingId, address indexed buyer, uint256 amount, uint256 totalPrice);
    event ListingCancelled(uint256 indexed listingId);
    event TokenURIUpdated(uint256 indexed tokenId, string newUri);

    constructor(
        string memory _name,
        string memory _symbol,
        string memory baseURI_,
        address _feeRecipient
    ) ERC1155(baseURI_) Ownable(msg.sender) {
        name = _name;
        symbol = _symbol;
        _baseURI = baseURI_;
        feeRecipient = _feeRecipient;
    }

    // --- Minting ---

    function mint(address to, uint256 tokenId, uint256 amount, bytes memory data) external onlyOwner {
        tokenExists[tokenId] = true;
        _mint(to, tokenId, amount, data);
    }

    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) external onlyOwner {
        for (uint256 i = 0; i < ids.length; i++) {
            tokenExists[ids[i]] = true;
        }
        _mintBatch(to, ids, amounts, data);
    }

    // --- Dynamic Metadata ---

    function setBaseURI(string memory newBaseURI) external onlyOwner {
        _baseURI = newBaseURI;
    }

    function setTokenURI(uint256 tokenId, string memory tokenURI_) external onlyOwner {
        _tokenURIs[tokenId] = tokenURI_;
        emit TokenURIUpdated(tokenId, tokenURI_);
        emit URI(uri(tokenId), tokenId);
    }

    function uri(uint256 tokenId) public view override returns (string memory) {
        string memory _tokenURI = _tokenURIs[tokenId];
        if (bytes(_tokenURI).length > 0) {
            return _tokenURI;
        }
        return string(abi.encodePacked(_baseURI, tokenId.toString(), ".json"));
    }

    // --- Crafting ---

    function createRecipe(
        uint256[] calldata inputTokenIds,
        uint256[] calldata inputAmounts,
        uint256 outputTokenId,
        uint256 outputAmount
    ) external onlyOwner returns (uint256 recipeId) {
        require(inputTokenIds.length > 0, "No inputs");
        require(inputTokenIds.length == inputAmounts.length, "Length mismatch");
        require(outputAmount > 0, "Zero output");

        recipeId = _nextRecipeId++;
        recipes[recipeId] = CraftingRecipe({
            inputTokenIds: inputTokenIds,
            inputAmounts: inputAmounts,
            outputTokenId: outputTokenId,
            outputAmount: outputAmount,
            active: true
        });

        tokenExists[outputTokenId] = true;

        emit RecipeCreated(recipeId, inputTokenIds, inputAmounts, outputTokenId, outputAmount);
    }

    function toggleRecipe(uint256 recipeId, bool active) external onlyOwner {
        require(recipes[recipeId].outputAmount > 0, "Recipe not found");
        recipes[recipeId].active = active;
        emit RecipeToggled(recipeId, active);
    }

    function craft(uint256 recipeId) external nonReentrant {
        CraftingRecipe storage recipe = recipes[recipeId];
        require(recipe.active, "Recipe inactive");

        for (uint256 i = 0; i < recipe.inputTokenIds.length; i++) {
            require(
                balanceOf(msg.sender, recipe.inputTokenIds[i]) >= recipe.inputAmounts[i],
                "Insufficient input tokens"
            );
        }

        for (uint256 i = 0; i < recipe.inputTokenIds.length; i++) {
            _burn(msg.sender, recipe.inputTokenIds[i], recipe.inputAmounts[i]);
        }

        _mint(msg.sender, recipe.outputTokenId, recipe.outputAmount, "");

        emit ItemCrafted(msg.sender, recipeId, recipe.outputTokenId, recipe.outputAmount);
    }

    function getRecipe(uint256 recipeId) external view returns (
        uint256[] memory inputTokenIds,
        uint256[] memory inputAmounts,
        uint256 outputTokenId,
        uint256 outputAmount,
        bool active
    ) {
        CraftingRecipe storage r = recipes[recipeId];
        return (r.inputTokenIds, r.inputAmounts, r.outputTokenId, r.outputAmount, r.active);
    }

    // --- Marketplace ---

    function list(uint256 tokenId, uint256 amount, uint256 pricePerUnit) external nonReentrant returns (uint256 listingId) {
        require(amount > 0, "Zero amount");
        require(pricePerUnit > 0, "Zero price");
        require(balanceOf(msg.sender, tokenId) >= amount, "Insufficient balance");
        require(isApprovedForAll(msg.sender, address(this)), "Marketplace not approved");

        listingId = _nextListingId++;
        listings[listingId] = Listing({
            seller: msg.sender,
            tokenId: tokenId,
            amount: amount,
            pricePerUnit: pricePerUnit,
            active: true
        });

        emit Listed(listingId, msg.sender, tokenId, amount, pricePerUnit);
    }

    function buy(uint256 listingId, uint256 amount) external payable nonReentrant {
        Listing storage listing = listings[listingId];
        require(listing.active, "Listing inactive");
        require(amount > 0 && amount <= listing.amount, "Invalid amount");

        uint256 totalPrice = amount * listing.pricePerUnit;
        require(msg.value == totalPrice, "Wrong payment");

        listing.amount -= amount;
        if (listing.amount == 0) {
            listing.active = false;
        }

        uint256 fee = (totalPrice * marketplaceFee) / FEE_DENOMINATOR;
        uint256 sellerProceeds = totalPrice - fee;

        _safeTransferFrom(listing.seller, msg.sender, listing.tokenId, amount, "");

        (bool sent, ) = payable(listing.seller).call{value: sellerProceeds}("");
        require(sent, "Payment failed");

        if (fee > 0) {
            (bool feeSent, ) = payable(feeRecipient).call{value: fee}("");
            require(feeSent, "Fee transfer failed");
        }

        emit Sale(listingId, msg.sender, amount, totalPrice);
    }

    function cancelListing(uint256 listingId) external {
        Listing storage listing = listings[listingId];
        require(listing.seller == msg.sender, "Not seller");
        require(listing.active, "Already inactive");

        listing.active = false;
        emit ListingCancelled(listingId);
    }

    // --- Admin ---

    function setMarketplaceFee(uint256 newFee) external onlyOwner {
        require(newFee <= 1000, "Fee too high"); // max 10%
        marketplaceFee = newFee;
    }

    function setFeeRecipient(address newRecipient) external onlyOwner {
        require(newRecipient != address(0), "Zero address");
        feeRecipient = newRecipient;
    }

    // --- Overrides ---

    function _update(address from, address to, uint256[] memory ids, uint256[] memory values)
        internal
        override(ERC1155, ERC1155Supply)
    {
        super._update(from, to, ids, values);
    }
}