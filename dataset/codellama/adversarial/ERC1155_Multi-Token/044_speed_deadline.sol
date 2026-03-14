SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC1155/ERC1155.sol";

contract MultiToken is ERC1155 {
    constructor() ERC1155("MultiToken", "MTK") {
        _mint(msg.sender, 1, 100, "https://token-cdn-domain/{id}.json");
    }
}