// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";

contract CustomERC1155 is ERC1155, Ownable, ERC1155Supply {
    struct TokenData {
        uint256 supplyCap;
        uint256 royalty;
    }

    mapping(uint256 => TokenData) private _tokenData;

    constructor(string memory uri) ERC1155(uri) {}

    function setTokenData(uint256 tokenId, uint256 supplyCap, uint256 royalty) external onlyOwner {
        require(royalty <= 10000, "Royalty too high"); // max 100%
        _tokenData[tokenId] = TokenData(supplyCap, royalty);
    }

    function mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) external onlyOwner {
        for (uint256 i = 0; i < ids.length; i++) {
            uint256 tokenId = ids[i];
            uint256 newSupply = totalSupply(tokenId) + amounts[i];
            require(newSupply <= _tokenData[tokenId].supplyCap, "Exceeds supply cap");
        }
        _mintBatch(to, ids, amounts, data);
    }

    function getSupplyCap(uint256 tokenId) external view returns (uint256) {
        return _tokenData[tokenId].supplyCap;
    }

    function getRoyalty(uint256 tokenId) external view returns (uint256) {
        return _tokenData[tokenId].royalty;
    }

    // Override functions required by Solidity

    function _beforeTokenTransfer(address operator, address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        internal
        override(ERC1155, ERC1155Supply)
    {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }
}