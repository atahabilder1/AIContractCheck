// Source: OpenZeppelin Contracts (GitHub)
// Original Path: mocks/TimelockReentrant.sol
// License: MIT
// Collected: 2026-03-16T17:54:55.912718

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Address} from "../utils/Address.sol";

contract TimelockReentrant {
    address private _reenterTarget;
    bytes private _reenterData;
    bool _reentered;

    function disableReentrancy() external {
        _reentered = true;
    }

    function enableReentrancy(address target, bytes calldata data) external {
        _reenterTarget = target;
        _reenterData = data;
    }

    function reenter() external {
        if (!_reentered) {
            _reentered = true;
            Address.functionCall(_reenterTarget, _reenterData);
        }
    }
}
