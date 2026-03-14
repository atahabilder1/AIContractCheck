// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";

contract DynamicCraftableERC1155 is ERC1155, ERC1155Burnable, ERC1155Supply, Ownable {
    using Strings for uint256;

    // Structure to define a craftable recipe
    struct Recipe {
        uint256 tokenId;         // The ID of the token to be minted
        uint256 supply;          // The number of this token to mint per craft
        uint256[] requiredTokenIds; // Array of token IDs required for crafting
        uint256[] requiredAmounts;  // Array of amounts for each required token ID
    }

    // Mapping from the crafted token ID to its recipe
    mapping(uint256 => Recipe) public recipes;
    // Mapping to check if a token ID is defined as a craftable output
    mapping(uint256 => bool) public isCraftableOutput;

    // Base URI for dynamic metadata
    string public baseURI;

    // Event for successful crafting
    event TokenCrafted(address indexed crafter, uint256 outputTokenId, uint256 outputAmount);

    // Event for adding/updating a recipe
    event RecipeUpdated(uint256 outputTokenId, uint256 supply, uint256[] requiredTokenIds, uint256[] requiredAmounts);

    // Event for removing a recipe
    event RecipeRemoved(uint256 outputTokenId);

    // --- Constructor ---
    constructor(string memory _baseURI) ERC1155(_baseURI) Ownable(msg.sender) {
        baseURI = _baseURI;
    }

    // --- Minting ---
    /**
     * @notice Mints a new token. Only callable by the owner.
     * @param _id The ID of the token to mint.
     * @param _amount The amount of tokens to mint.
     * @param _data Optional data to send with the mint.
     */
    function mint(uint256 _id, uint256 _amount, bytes memory _data) public onlyOwner {
        _mint(_id, _amount);
        _doSafeTransferTransfer(address(this), msg.sender, _id, _amount, _data);
    }

    /**
     * @notice Mints multiple tokens. Only callable by the owner.
     * @param _ids Array of token IDs to mint.
     * @param _amounts Array of amounts for each token ID.
     * @param _data Optional data to send with the mint.
     */
    function mintBatch(uint256[] memory _ids, uint256[] memory _amounts, bytes memory _data) public onlyOwner {
        require(_ids.length == _amounts.length, "ERC1155: ids and amounts length mismatch");
        for (uint256 i = 0; i < _ids.length; i++) {
            _mint(_ids[i], _amounts[i]);
        }
        _doSafeBatchTransferTransfer(address(this), msg.sender, _ids, _amounts, _data);
    }

    // --- Crafting ---
    /**
     * @notice Defines or updates a crafting recipe. Only callable by the owner.
     * @param _outputTokenId The ID of the token to be minted by this recipe.
     * @param _supply The number of output tokens to mint per craft.
     * @param _requiredTokenIds Array of token IDs required for crafting.
     * @param _requiredAmounts Array of amounts for each required token ID.
     */
    function updateRecipe(
        uint256 _outputTokenId,
        uint256 _supply,
        uint256[] memory _requiredTokenIds,
        uint256[] memory _requiredAmounts
    ) public onlyOwner {
        require(_requiredTokenIds.length == _requiredAmounts.length, "ERC1155: required ids and amounts length mismatch");
        require(_requiredAmounts.length > 0, "ERC1155: recipe must require at least one token");
        require(_supply > 0, "ERC1155: output supply must be greater than zero");

        recipes[_outputTokenId] = Recipe({
            tokenId: _outputTokenId,
            supply: _supply,
            requiredTokenIds: _requiredTokenIds,
            requiredAmounts: _requiredAmounts
        });
        isCraftableOutput[_outputTokenId] = true;
        emit RecipeUpdated(_outputTokenId, _supply, _requiredTokenIds, _requiredAmounts);
    }

    /**
     * @notice Removes a crafting recipe. Only callable by the owner.
     * @param _outputTokenId The ID of the token whose recipe to remove.
     */
    function removeRecipe(uint256 _outputTokenId) public onlyOwner {
        require(isCraftableOutput[_outputTokenId], "ERC1155: recipe does not exist");
        delete recipes[_outputTokenId];
        isCraftableOutput[_outputTokenId] = false;
        emit RecipeRemoved(_outputTokenId);
    }

    /**
     * @notice Crafts a token by burning required input tokens and minting the output token.
     * @param _outputTokenId The ID of the token to craft.
     * @param _craftAmount The number of times to perform the craft.
     */
    function craftToken(uint256 _outputTokenId, uint256 _craftAmount) public {
        require(isCraftableOutput[_outputTokenId], "ERC1155: invalid output token ID for crafting");
        require(_craftAmount > 0, "ERC1155: craft amount must be greater than zero");

        Recipe storage recipe = recipes[_outputTokenId];
        uint256 totalOutputAmount = recipe.supply * _craftAmount;

        // Burn required tokens from the caller
        for (uint256 i = 0; i < recipe.requiredTokenIds.length; i++) {
            uint256 requiredTokenId = recipe.requiredTokenIds[i];
            uint256 requiredAmount = recipe.requiredAmounts[i] * _craftAmount;
            require(balanceOf(msg.sender, requiredTokenId) >= requiredAmount, "ERC1155: insufficient balance of required token");
            _burn(msg.sender, requiredTokenId, requiredAmount);
        }

        // Mint new tokens to the caller
        _mint(msg.sender, totalOutputAmount);

        emit TokenCrafted(msg.sender, _outputTokenId, totalOutputAmount);
    }

    // --- Metadata ---
    /**
     * @dev Sets the base URI for all token metadata.
     * @param _baseURI The new base URI.
     */
    function setBaseURI(string memory _baseURI) public onlyOwner {
        baseURI = _baseURI;
        emit URI(_baseURI, 0); // Event from ERC1155 to signal URI change
    }

    /**
     * @dev Returns the URI for a given token ID.
     * This implementation assumes dynamic metadata based on token ID.
     * You can extend this to fetch data from an external source or use storage.
     * @param _tokenId The ID of the token.
     * @return The URI for the token.
     */
    function uri(uint256 _tokenId) public view override returns (string memory) {
        // Example: If baseURI is "ipfs://Qm...", and _tokenId is 1, this returns "ipfs://Qm.../1"
        // For more complex dynamic metadata, you might want to:
        // 1. Fetch data from an external API based on _tokenId.
        // 2. Store metadata directly in the contract (for small datasets).
        // 3. Use a mapping to associate token IDs with specific metadata URIs.

        // The default implementation from OpenZeppelin concatenates baseURI with tokenId.
        // If you need more complex dynamic logic, you might override this.
        return string(abi.encodePacked(baseURI, _tokenId.toString()));
    }

    // --- Marketplace Integration ---
    // This contract is designed to be compatible with standard ERC1155 marketplaces.
    // Marketplaces typically interact with ERC1155 tokens by calling:
    // - `balanceOf(owner, tokenId)` to check balances.
    // - `safeTransferFrom(from, to, tokenId, amount, data)` for transfers.
    // - `setApprovalForAll(operator, approved)` to allow operators (like a marketplace contract)
    //   to transfer tokens on behalf of the owner.

    // To facilitate listing and selling, a marketplace might also require:
    // - A way to set prices.
    // - A way to handle payments (e.g., accepting ETH or ERC20 tokens).
    // This contract itself doesn't implement a marketplace but is designed to be used by one.
    // For example, a marketplace contract would have functions like:
    // `listToken(tokenId, amount, price)`
    // `buyToken(listingId)`
    // These marketplace functions would call `setApprovalForAll` on this ERC1155 contract
    // and then `safeTransferFrom` to move tokens upon purchase.

    // --- Overrides for ERC1155Supply and ERC1155Burnable ---
    // These are already handled by importing the respective extensions.
    // The `_burn` and `_mint` functions are correctly overridden by ERC1155Supply.
    // The `burn` and `burnBatch` functions are provided by ERC1155Burnable.

    // --- Helper Functions ---
    /**
     * @dev Checks if a given token ID is defined as a craftable output.
     * @param _tokenId The token ID to check.
     * @return True if the token ID is a craftable output, false otherwise.
     */
    function isCraftable(uint256 _tokenId) public view returns (bool) {
        return isCraftableOutput[_tokenId];
    }

    /**
     * @dev Gets the recipe for a given output token ID.
     * @param _outputTokenId The token ID to get the recipe for.
     * @return _supply The number of output tokens per craft.
     * @return _requiredTokenIds Array of required token IDs.
     * @return _requiredAmounts Array of required token amounts.
     */
    function getRecipe(uint256 _outputTokenId)
        public
        view
        returns (
            uint256 _supply,
            uint256[] memory _requiredTokenIds,
            uint256[] memory _requiredAmounts
        )
    {
        require(isCraftableOutput[_outputTokenId], "ERC1155: recipe does not exist");
        Recipe storage recipe = recipes[_outputTokenId];
        return (recipe.supply, recipe.requiredTokenIds, recipe.requiredAmounts);
    }
}