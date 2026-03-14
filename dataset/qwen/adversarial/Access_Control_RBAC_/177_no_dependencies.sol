// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract AccessControl {
    mapping(bytes32 => mapping(address => bool)) private roleMembers;
    mapping(bytes32 => mapping(address => bool)) private roleAdmins;

    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleAdminChanged(bytes32 indexed role, address indexed newAdmin, address indexed sender);

    modifier onlyRole(bytes32 role) {
        require(hasRole(role, msg.sender), "AccessControl: caller does not have the role");
        _;
    }

    modifier onlyRoleAdmin(bytes32 role) {
        require(isRoleAdmin(role, msg.sender), "AccessControl: caller is not the role admin");
        _;
    }

    function hasRole(bytes32 role, address account) public view returns (bool) {
        return roleMembers[role][account];
    }

    function isRoleAdmin(bytes32 role, address account) public view returns (bool) {
        return roleAdmins[role][account];
    }

    function grantRole(bytes32 role, address account) public onlyRoleAdmin(role) {
        require(!hasRole(role, account), "AccessControl: account already has role");
        roleMembers[role][account] = true;
        emit RoleGranted(role, account, msg.sender);
    }

    function revokeRole(bytes32 role, address account) public onlyRoleAdmin(role) {
        require(hasRole(role, account), "AccessControl: account does not have role");
        roleMembers[role][account] = false;
        emit RoleRevoked(role, account, msg.sender);
    }

    function changeRoleAdmin(bytes32 role, address newAdmin) public onlyRoleAdmin(role) {
        require(newAdmin != address(0), "AccessControl: new admin is the zero address");
        roleAdmins[role][msg.sender] = false;
        roleAdmins[role][newAdmin] = true;
        emit RoleAdminChanged(role, newAdmin, msg.sender);
    }

    function renounceRole(bytes32 role, address account) public {
        require(account == msg.sender, "AccessControl: can only renounce roles for self");
        require(hasRole(role, account), "AccessControl: account does not have role");
        roleMembers[role][account] = false;
        emit RoleRevoked(role, account, msg.sender);
    }
}