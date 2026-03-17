// Source: OpenZeppelin Contracts (GitHub)
// Original Path: mocks/token/ERC20ExcessDecimalsMock.sol
// License: MIT
// Collected: 2026-03-16T17:54:55.906641

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

contract ERC20ExcessDecimalsMock {
    function decimals() public pure returns (uint256) {
        return type(uint256).max;
    }
}
