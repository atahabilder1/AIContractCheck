// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract HackathonNFT is ERC721, Ownable {
    using Strings for uint256;
    string private baseTokenURI;

    constructor() ERC721("HackathonNFT", "HNFT") {}

    function setBaseTokenURI(string memory _baseTokenURI) external onlyOwner {
        baseTokenURI = _baseTokenURI;
    }

    function mintNFT(address to, uint256 tokenId) public onlyOwner {
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, string(abi.encodePacked(baseTokenURI, tokenId.toString())));
    }
}