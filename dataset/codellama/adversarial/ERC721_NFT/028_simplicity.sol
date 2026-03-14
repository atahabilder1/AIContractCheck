// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MyNFT is ERC721 {
    constructor() ERC721("MyNFT", "MNT") {}

    function mint(address to, uint256 tokenId) public {
        _mint(to, tokenId);
    }

    function burn(uint256 tokenId) public {
        _burn(tokenId);
    }

    function ownerOf(uint256 tokenId) public view returns (address) {
        return _ownerOf(tokenId);
    }
}