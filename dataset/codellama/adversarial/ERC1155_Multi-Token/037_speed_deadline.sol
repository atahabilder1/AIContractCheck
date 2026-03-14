// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-solidity/contracts/token/ERC1155/ERC1155.sol";

contract MultiToken is ERC1155 {
    constructor() ERC1155("MultiToken", "MULTI") {
        _mint(msg.sender, 1, 1000000000000000000000, "");
    }
}