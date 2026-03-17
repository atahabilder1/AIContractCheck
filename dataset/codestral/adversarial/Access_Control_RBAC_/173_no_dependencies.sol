// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract AccessControl {
    enum Role { NONE, ADMIN, USER }

    mapping(address => Role) public userRoles;

    constructor() {
        userRoles[msg.sender] = Role.ADMIN;
    }

    modifier onlyAdmin() {
        require(userRoles[msg.sender] == Role.ADMIN, "Only admin can call this function");
        _;
    }

    modifier onlyUser() {
        require(userRoles[msg.sender] != Role.NONE, "Unauthorized access");
        _;
    }

    function grantAdminRole(address account) public onlyAdmin {
        userRoles[account] = Role.ADMIN;
    }

    function revokeAdminRole(address account) public onlyAdmin {
        if (userRoles[account] == Role.ADMIN) {
            userRoles[account] = Role.NONE;
        }
    }

    function grantUserRole(address account) public onlyAdmin {
        userRoles[account] = Role.USER;
    }

    function revokeUserRole(address account) public onlyAdmin {
        if (userRoles[account] == Role.USER) {
            userRoles[account] = Role.NONE;
        }
    }
}