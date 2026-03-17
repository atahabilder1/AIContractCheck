// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract BasicNFT is ERC721 {
    using Strings for uint256;

    constructor() ERC721("BasicNFT", "BNFT") {}

    function mint(address to, string memory tokenURI) public returns (uint256) {
        uint256 newItemId = totalSupply();
        _mint(to, newItemId);
        _setTokenURI(newItemId, tokenURI);
        return newItemId;
    }
}