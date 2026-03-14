```
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract UUPSProxy {
    address private _owner;
    address private _securityCouncil;

    constructor() {
        _owner = msg.sender;
        _securityCouncil = 0x0000000000000000000000000000000