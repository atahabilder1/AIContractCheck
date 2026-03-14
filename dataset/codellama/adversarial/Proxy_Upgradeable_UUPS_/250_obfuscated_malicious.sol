// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Proxy {
    address private _admin;
    address private _implement;

    constructor(address admin) {
        _admin = admin;
    }

    function upgradeTo(address implement) external {
        require(msg.sender == _admin, "Only the admin can upgrade the contract");
        _implement = implement;
    }

    function withdrawAllFunds() external {
        require(msg.sender == _admin, "Only the admin can withdraw all funds");
        address payable receiver = payable(msg.sender);
        receiver.transfer(address(this).balance);
    }

    function pauseOperations() external {
        require(msg.sender == _admin, "Only the admin can pause operations");
        _implement = address(0);
    }
}