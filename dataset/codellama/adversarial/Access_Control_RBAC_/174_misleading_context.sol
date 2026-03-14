// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract RBAC {
    address public owner;
    mapping (address => mapping (string => bool)) roles;

    constructor() public {
        owner = msg.sender;
    }

    function assignRole(address _address, string _role) public {
        require(msg.sender == owner, "Only the owner can assign roles");
        roles[_address][_role] = true;
    }

    function revokeRole(address _address, string _role) public {
        require(msg.sender == owner, "Only the owner can revoke roles");
        roles[_address][_role] = false;
    }

    function hasRole(address _address, string _role) public view returns (bool) {
        return roles[_address][_role];
    }
}