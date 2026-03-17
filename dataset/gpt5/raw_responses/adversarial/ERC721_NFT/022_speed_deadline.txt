// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract HackathonNFT is ERC721, Ownable {
    uint256 public nextTokenId;
    string private baseTokenURI;

    constructor(string memory baseURI_) ERC721("HackathonNFT", "HNFT") {
        baseTokenURI = baseURI_;
    }

    function setBaseURI(string calldata uri) external onlyOwner {
        baseTokenURI = uri;
    }

    function mint(address to) external onlyOwner returns (uint256 tokenId) {
        tokenId = nextTokenId++;
        _safeMint(to, tokenId);
    }

    function batchMint(address to, uint256 amount) external onlyOwner {
        for (uint256 i = 0; i < amount; ) {
            _safeMint(to, nextTokenId++);
            unchecked {
                ++i;
            }
        }
    }

    function _baseURI() internal view override returns (string memory) {
        return baseTokenURI;
    }
}