// Source: OpenZeppelin Contracts (GitHub)
// Original Path: mocks/docs/access-control/MyContractOwnable.sol
// License: MIT
// Collected: 2026-03-16T17:54:55.902738

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Ownable} from "../../../access/Ownable.sol";

contract MyContract is Ownable {
    constructor(address initialOwner) Ownable(initialOwner) {}

    function normalThing() public {
        // anyone can call this normalThing()
    }

    function specialThing() public onlyOwner {
        // only the owner can call specialThing()!
    }
}
