// Source: OpenZeppelin Contracts (GitHub)
// Original Path: mocks/token/ERC20ReturnFalseMock.sol
// License: MIT
// Collected: 2026-03-16T17:54:55.906736

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {ERC20} from "../../token/ERC20/ERC20.sol";

abstract contract ERC20ReturnFalseMock is ERC20 {
    function transfer(address, uint256) public pure override returns (bool) {
        return false;
    }

    function transferFrom(address, address, uint256) public pure override returns (bool) {
        return false;
    }

    function approve(address, uint256) public pure override returns (bool) {
        return false;
    }
}
