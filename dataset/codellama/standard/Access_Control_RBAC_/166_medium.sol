// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract RBAC {
    struct Role {
        mapping(address => bool) members;
        mapping(string => bool) permissions;
    }

    mapping(string => Role) roles;

    modifier onlyRole(string memory role) {
        require(msg.sender.isRole(role), "Only members of the specified role can perform this action");
        _;
    }

    function grantRole(string memory role, address member) public onlyRole("admin") {
        roles[role].members[member] = true;
    }

    function revokeRole(string memory role, address member) public onlyRole("admin") {
        roles[role].members[member] = false;
    }

    function isRole(string memory role, address member) public view returns (bool) {
        return roles[role].members[member];
    }
}