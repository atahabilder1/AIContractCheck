// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

contract RoleBasedAccessControl {
    enum Role { ADMIN, MANAGER, USER }

    mapping(address => Role) private userRoles;

    constructor() {
        userRoles[msg.sender] = Role.ADMIN;
    }

    modifier onlyRole(Role _role) {
        require(userRoles[msg.sender] == _role, "Access Denied");
        _;
    }

    function grantRole(address account, Role role) public onlyRole(Role.ADMIN) {
        userRoles[account] = role;
    }

    function revokeRole(address account) public onlyRole(Role.ADMIN) {
        delete userRoles[account];
    }
}