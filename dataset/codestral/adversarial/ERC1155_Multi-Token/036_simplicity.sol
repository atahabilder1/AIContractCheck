// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract SimpleMultiToken is ERC1155 {
    constructor() ERC1155("https://your-metadata-url/{id}.json") {}
}