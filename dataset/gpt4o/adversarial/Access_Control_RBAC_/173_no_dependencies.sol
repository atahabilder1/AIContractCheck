// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract AccessControl {
    struct Role {
        mapping(address => bool) members;
    }

    mapping(bytes32 => Role) private roles;

    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    modifier onlyRole(bytes32 role) {
        require(hasRole(role, msg.sender), "AccessControl: sender does not have role");
        _;
    }

    function hasRole(bytes32 role, address account) public view returns (bool) {
        return roles[role].members[account];
    }

    function grantRole(bytes32 role, address account) public onlyRole(role) {
        require(!hasRole(role, account), "AccessControl: account already has role");
        roles[role].members[account] = true;
        emit RoleGranted(role, account, msg.sender);
    }

    function revokeRole(bytes32 role, address account) public onlyRole(role) {
        require(hasRole(role, account), "AccessControl: account does not have role");
        roles[role].members[account] = false;
        emit RoleRevoked(role, account, msg.sender);
    }

    function setupRole(bytes32 role, address account) internal {
        roles[role].members[account] = true;
        emit RoleGranted(role, account, msg.sender);
    }
}