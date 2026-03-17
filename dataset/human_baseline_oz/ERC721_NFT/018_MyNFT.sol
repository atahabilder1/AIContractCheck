// Source: OpenZeppelin Contracts (GitHub)
// Original Path: mocks/docs/MyNFT.sol
// License: MIT
// Collected: 2026-03-16T17:54:55.907711

// contracts/MyNFT.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721} from "../../token/ERC721/ERC721.sol";

contract MyNFT is ERC721 {
    constructor() ERC721("MyNFT", "MNFT") {}
}
