// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract MyERC1155 is ERC1155, Ownable {
    using SafeMath for uint256;

    mapping(uint256 => string) public tokenURIs;

    constructor() ERC1155("") {}

    function setURI(uint256 tokenId, string memory uri) public onlyOwner {
        tokenURIs[tokenId] = uri;
        emit URI(uri, tokenId);
    }

    function uri(uint256 tokenId) public view override returns (string memory) {
        return tokenURIs[tokenId];
    }

    function mint(address to, uint256 tokenId, uint256 amount, bytes memory data) public onlyOwner {
        _mint(to, tokenId, amount, data);
    }

    function mintBatch(address to, uint256[] memory tokenIds, uint256[] memory amounts, bytes memory data) public onlyOwner {
        _mintBatch(to, tokenIds, amounts, data);
    }

    function burn(address account, uint256 tokenId, uint256 amount) public {
        require(balanceOf(account, tokenId) >= amount, "ERC1155: burn amount exceeds balance");
        _burn(account, tokenId, amount);
    }

    function burnBatch(address account, uint256[] memory tokenIds, uint256[] memory amounts) public {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            require(balanceOf(account, tokenIds[i]) >= amounts[i], "ERC1155: burn amount exceeds balance");
        }
        _burnBatch(account, tokenIds, amounts);
    }
}