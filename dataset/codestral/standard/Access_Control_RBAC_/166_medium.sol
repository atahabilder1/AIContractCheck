// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract RoleBasedAccessControl {
    enum Role { ADMIN, MANAGER, USER }

    mapping(address => Role) private userRoles;

    constructor() {
        userRoles[msg.sender] = Role.ADMIN;
    }

    modifier onlyAdmin() {
        require(userRoles[msg.sender] == Role.ADMIN, "Only admin can perform this action");
        _;
    }

    modifier onlyManager() {
        require(userRoles[msg.sender] <= Role.MANAGER, "Only manager or above can perform this action");
        _;
    }

    modifier onlyUser() {
        require(userRoles[msg.sender] != Role.ADMIN && userRoles[msg.sender] != Role.MANAGER, "Only regular users can perform this action");
        _;
    }

    function grantRole(address account, Role role) public onlyAdmin {
        require(role < userRoles[msg.sender], "Cannot grant a higher or equal role");
        userRoles[account] = role;
    }

    function revokeRole(address account) public onlyAdmin {
        userRoles[account] = Role.USER;
    }

    // Example functions with modifiers
    function adminFunction() public onlyAdmin {}
    function managerFunction() public onlyManager {}
    function userFunction() public onlyUser {}
}