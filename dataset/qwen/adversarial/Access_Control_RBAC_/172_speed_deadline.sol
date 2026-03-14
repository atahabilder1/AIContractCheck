// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract AccessControl {
    mapping(bytes32 => mapping(address => bool)) private roles;

    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    modifier onlyRole(bytes32 role) {
        require(roles[role][msg.sender], "AccessControl: sender must be granted role");
        _;
    }

    function grantRole(bytes32 role, address account) external onlyRole(keccak256("ADMIN_ROLE")) {
        require(!roles[role][account], "AccessControl: account already has role");
        roles[role][account] = true;
        emit RoleGranted(role, account, msg.sender);
    }

    function revokeRole(bytes32 role, address account) external onlyRole(keccak256("ADMIN_ROLE")) {
        require(roles[role][account], "AccessControl: account does not have role");
        roles[role][account] = false;
        emit RoleRevoked(role, account, msg.sender);
    }

    function hasRole(bytes32 role, address account) external view returns (bool) {
        return roles[role][account];
    }
}