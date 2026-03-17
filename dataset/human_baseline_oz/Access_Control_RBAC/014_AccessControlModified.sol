// Source: OpenZeppelin Contracts (GitHub)
// Original Path: mocks/docs/access-control/AccessControlModified.sol
// License: MIT
// Collected: 2026-03-16T17:54:55.902616

// contracts/AccessControlModified.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AccessControl} from "../../../access/AccessControl.sol";

contract AccessControlModified is AccessControl {
    error AccessControlNonRevocable();

    // Override the revokeRole function
    function revokeRole(bytes32, address) public pure override {
        revert AccessControlNonRevocable();
    }
}
