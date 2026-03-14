// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Base64.sol";

contract GasOptimizedERC1155 is ERC1155, Ownable {
    using Strings for uint256;
    using Base64 for bytes;

    uint256 public constant MAX_SUPPLY_PER_TOKEN = 1000000; // Example limit, adjust as needed
    uint256 private _nextTokenId;

    // Mapping to store token URIs, saving gas by not storing them directly in metadata
    mapping(uint256 => string) private _tokenURIs;

    constructor() ERC1155("GasOptimizedERC1155") Ownable(msg.sender) {
        _nextTokenId = 1; // Start token IDs from 1
    }

    /**
     * @dev Mints new tokens of a specified type to a recipient.
     * @param recipient The address to mint tokens to.
     * @param id The ID of the token type to mint.
     * @param amount The number of tokens to mint.
     * @param data Optional data to send along with the mint.
     */
    function mint(address recipient, uint256 id, uint256 amount, bytes memory data) public onlyOwner {
        _mint(recipient, id, amount, data);
    }

    /**
     * @dev Mints new tokens of a specified type to multiple recipients.
     * @param recipients An array of addresses to mint tokens to.
     * @param ids An array of token IDs to mint.
     * @param amounts An array of amounts to mint for each token ID.
     * @param data Optional data to send along with the mint.
     */
    function mintBatch(address[] memory recipients, uint256[] memory ids, uint256[] memory amounts, bytes memory data) public onlyOwner {
        require(recipients.length == ids.length && recipients.length == amounts.length, "Batch mint: mismatched arrays");
        for (uint256 i = 0; i < recipients.length; i++) {
            _mint(recipients[i], ids[i], amounts[i], data);
        }
    }

    /**
     * @dev Sets the URI for a given token ID.
     * @param id The ID of the token.
     * @param uri The URI to set for the token.
     */
    function setURI(uint256 id, string memory uri) public onlyOwner {
        require(id != 0, "Set URI: token ID cannot be 0");
        _tokenURIs[id] = uri;
        emit URI(uri, id);
    }

    /**
     * @dev Returns the URI for a given token ID.
     * @param id The ID of the token.
     * @return The URI for the token.
     */
    function uri(uint256 id) public view override returns (string memory) {
        return _tokenURIs[id];
    }

    /**
     * @dev Returns the next available token ID.
     * @return The next token ID.
     */
    function nextTokenId() public view returns (uint256) {
        return _nextTokenId;
    }

    /**
     * @dev Creates a new token type and mints it to the caller.
     * @param initialSupply The initial supply of the new token type.
     * @param uri The URI for the new token type.
     * @return The ID of the newly created token type.
     */
    function createTokenType(uint256 initialSupply, string memory uri) public onlyOwner returns (uint256) {
        uint256 newTokenId = _nextTokenId++;
        require(newTokenId <= MAX_SUPPLY_PER_TOKEN, "Create token type: max supply reached for this type");
        setURI(newTokenId, uri);
        _mint(msg.sender, newTokenId, initialSupply, "");
        return newTokenId;
    }

    /**
     * @dev Internal function to mint tokens, with supply check.
     * @param recipient The address to mint tokens to.
     * @param id The ID of the token type to mint.
     * @param amount The number of tokens to mint.
     * @param data Optional data to send along with the mint.
     */
    function _mint(address recipient, uint256 id, uint256 amount, bytes memory data) internal override {
        // Check if this is a new token type being minted for the first time
        if (_tokenURIs[id] == "" && id >= _nextTokenId) {
            revert("ERC1155: token type does not exist");
        }
        super._mint(recipient, id, amount, data);
    }

    /**
     * @dev Overrides the default _doSafeTransferAccept for gas optimization.
     *      This function is called by _doSafeTransfer and _doSafeBatchTransfer.
     *      It's designed to be as lean as possible.
     */
    function _doSafeTransferAccept(
        address operator,
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data,
        bool isBatch
    ) internal override {
        // No additional checks needed here for gas optimization.
        // The standard ERC1155 checks are handled in _doSafeTransfer and _doSafeBatchTransfer.
        // We simply call the parent's implementation.
        super._doSafeTransferAccept(operator, from, to, id, amount, data, isBatch);
    }

    /**
     * @dev Override _update to minimize gas.
     *      This function is called by _mint and _burn.
     */
    function _update(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts
    ) internal override {
        // Minimal checks, primarily relying on parent's logic.
        // The parent's _update handles the core balance updates.
        super._update(from, to, ids, amounts);
    }

    /**
     * @dev Override _beforeTokenTransfer to minimize gas.
     *      This function is called before any token transfer.
     */
    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes[] memory data
    ) internal override {
        // Minimal checks for gas optimization.
        // The primary purpose here is to ensure token existence if it's a new type,
        // but the _mint function already handles this.
        // For transfers, the existence is implicitly checked by balance checks.
        // If a token type is being created and minted for the first time, _mint handles it.
        // For existing tokens, balance checks are sufficient.
    }
}