// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract MinimalGasNFT is ERC721, Ownable {
    using Strings for uint256;

    bytes32 private constant BASE_URI = "https://your-base-uri.com/";
    uint256 public totalSupply;

    constructor() ERC721("MinimalGasNFT", "MNG") {}

    function safeMint(address to, string memory tokenURI) external onlyOwner {
        _safeMint(to, totalSupply);
        _setTokenURI(totalSupply, BASE_URI + uint256(keccak256(abi.encodePacked(tokenURI))).toHexString());
        totalSupply++;
    }
}