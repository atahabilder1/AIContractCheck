// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract DemoNFT is ERC721, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    constructor() ERC721("DemoNFT", "DNFT") {}

    function mint(address to) public onlyOwner {
        uint256 newItemId = _tokenIds.current();
        _tokenIds.increment();
        _safeMint(to, newItemId);
    }
}