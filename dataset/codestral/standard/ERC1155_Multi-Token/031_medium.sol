// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract MyERC1155 is IERC1155, Ownable {
    using SafeMath for uint256;

    mapping(uint256 => uint256) private _tokenSupplyCap;
    mapping(uint256 => uint96) private _royalties; // Per-token royalty percentage (0.01% - 100%)

    constructor() {}

    function setTokenSupplyCap(uint256 tokenId, uint256 cap) external onlyOwner {
        _tokenSupplyCap[tokenId] = cap;
    }

    function setRoyalty(uint256 tokenId, uint96 royaltyPercentage) external onlyOwner {
        require(royaltyPercentage <= 10000, "Royalty percentage exceeds maximum limit");
        _royalties[tokenId] = royaltyPercentage;
    }

    function batchMint(address[] memory to, uint256[] memory tokenIds, uint256[] memory amounts) external onlyOwner {
        require(to.length == tokenIds.length && tokenIds.length == amounts.length, "Input arrays must have the same length");
        for (uint256 i = 0; i < to.length; i++) {
            _mint(to[i], tokenIds[i], amounts[i]);
        }
    }

    function _beforeTokenTransfer(address operator, address from, address to, uint256[] memory ids, uint256[] memory values, bytes calldata data) internal override {
        require(ids.length == values.length, "Ids and values length must match");
        for (uint256 i = 0; i < ids.length; i++) {
            _transferSingle(operator, from, to, ids[i], values[i]);
            _distributeRoyalties(to, ids[i], values[i]);
        }
    }

    function _mint(address to, uint256 tokenId, uint256 amount) private {
        require(_totalSupply(tokenId).add(amount) <= _tokenSupplyCap[tokenId], "Minting exceeds supply cap");
        _mint(to, tokenId, amount, "");
    }

    function _distributeRoyalties(address to, uint256 tokenId, uint256 amount) private {
        uint96 royalty = _royalties[tokenId];
        if (royalty > 0 && msg.sender != owner()) {
            uint256 royaltyAmount = (amount * royalty) / 10000;
            payable(owner()).transfer(royaltyAmount);
        }
    }
}