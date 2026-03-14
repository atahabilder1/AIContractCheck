// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract AccessControl {
    // Define roles
    enum Role {
        Admin,
        Moderator,
        User
    }

    // Define permissions
    enum Permission {
        Create,
        Read,
        Update,
        Delete
    }

    // Define role assignments
    mapping(address => Role) public roles;

    // Define permission assignments
    mapping(address => mapping(Permission => bool)) public permissions;

    // Define events
    event RoleAssigned(address indexed user, Role role);
    event PermissionAssigned(address indexed user, Permission permission);
    event PermissionRevoked(address indexed user, Permission permission);

    // Define modifiers
    modifier onlyRole(Role role) {
        require(roles[msg.sender] == role, "Only the assigned role can perform this action");
        _;
    }

    modifier onlyPermission(Permission permission) {
        require(permissions[msg.sender][permission], "Only users with the assigned permission can perform this action");
        _;
    }

    // Define functions
    function assignRole(address user, Role role) public onlyRole(Role.Admin) {
        roles[user] = role;
        emit RoleAssigned(user, role);
    }

    function assignPermission(address user, Permission permission) public onlyRole(Role.Admin) {
        permissions[user][permission] = true;
        emit PermissionAssigned(user, permission);
    }

    function revokePermission(address user, Permission permission) public onlyRole(Role.Admin) {
        permissions[user][permission] = false;
        emit PermissionRevoked(user, permission);
    }

    function checkRole(address user) public view returns (Role) {
        return roles[user];
    }

    function checkPermission(address user, Permission permission) public view returns (bool) {
        return permissions[user][permission];
    }
}