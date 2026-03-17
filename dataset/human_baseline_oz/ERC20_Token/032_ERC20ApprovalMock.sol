// Source: OpenZeppelin Contracts (GitHub)
// Original Path: mocks/token/ERC20ApprovalMock.sol
// License: MIT
// Collected: 2026-03-16T17:54:55.905956

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "../../token/ERC20/ERC20.sol";

abstract contract ERC20ApprovalMock is ERC20 {
    function _approve(address owner, address spender, uint256 amount, bool) internal virtual override {
        super._approve(owner, spender, amount, true);
    }
}
