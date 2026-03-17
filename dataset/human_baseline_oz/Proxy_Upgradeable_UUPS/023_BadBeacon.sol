// Source: OpenZeppelin Contracts (GitHub)
// Original Path: mocks/proxy/BadBeacon.sol
// License: MIT
// Collected: 2026-03-16T17:54:55.912213

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

contract BadBeaconNoImpl {}

contract BadBeaconNotContract {
    function implementation() external pure returns (address) {
        return address(0x1);
    }
}
