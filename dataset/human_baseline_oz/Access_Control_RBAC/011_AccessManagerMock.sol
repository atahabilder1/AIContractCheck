// Source: OpenZeppelin Contracts (GitHub)
// Original Path: mocks/AccessManagerMock.sol
// License: MIT
// Collected: 2026-03-16T17:54:55.902463

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {AccessManager} from "../access/manager/AccessManager.sol";

contract AccessManagerMock is AccessManager {
    event CalledRestricted(address caller);
    event CalledUnrestricted(address caller);

    constructor(address initialAdmin) AccessManager(initialAdmin) {}

    function fnRestricted() public onlyAuthorized {
        emit CalledRestricted(msg.sender);
    }

    function fnUnrestricted() public {
        emit CalledUnrestricted(msg.sender);
    }
}
