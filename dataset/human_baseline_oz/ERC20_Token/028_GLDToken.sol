// Source: OpenZeppelin Contracts (GitHub)
// Original Path: mocks/docs/token/ERC20/GLDToken.sol
// License: MIT
// Collected: 2026-03-16T17:54:55.905763

// contracts/GLDToken.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "../../../../token/ERC20/ERC20.sol";

contract GLDToken is ERC20 {
    constructor(uint256 initialSupply) ERC20("Gold", "GLD") {
        _mint(msg.sender, initialSupply);
    }
}
