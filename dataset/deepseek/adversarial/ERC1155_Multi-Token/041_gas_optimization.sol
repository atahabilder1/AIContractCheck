// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract MyERC1155 is ERC1155, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;

    mapping(uint256 => string) private _tokenURIs;
    mapping(uint256 => uint256) private _balances;

    constructor() ERC1155("") {}

    function mint(address to, uint256 amount, string memory uri) public onlyOwner {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _balances[tokenId] += amount;
        _setTokenURI(tokenId, uri);
        _mint(to, tokenId, amount, "");
    }

    function balanceOf(address account, uint256 id) public view override returns (uint256) {
        return _balances[id];
    }

    function setTokenURI(uint256 tokenId, string memory uri) public onlyOwner {
        _setTokenURI(tokenId, uri);
    }

    function _setTokenURI(uint256 tokenId, string memory uri) internal {
        require(_exists(tokenId), "ERC1155: URI query for nonexistent token");
        _tokenURIs[tokenId] = uri;
    }

    function uri(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "ERC1155: URI query for nonexistent token");
        return _tokenURIs[tokenId];
    }

    function _exists(uint256 tokenId) internal view returns (bool) {
        return tokenId < _tokenIdCounter.current();
    }
}