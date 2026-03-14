// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract RBAC {
    mapping(address => mapping(bytes32 => bool)) private roles;
    mapping(bytes32 => bytes32) private adminRoles;

    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    constructor() {
        // Set the deployer as the default admin
        _grantRole(0x00, msg.sender); 
    }

    modifier onlyRole(bytes32 role) {
        require(hasRole(role, msg.sender), "RBAC: Access denied");
        _;
    }

    function grantRole(bytes32 role, address account) external onlyRole(getAdminRole(role)) {
        _grantRole(role, account);
    }

    function revokeRole(bytes32 role, address account) external onlyRole(getAdminRole(role)) {
        _revokeRole(role, account);
    }

    function renounceRole(bytes32 role) external {
        _revokeRole(role, msg.sender);
    }

    function hasRole(bytes32 role, address account) public view returns (bool) {
        return roles[account][role];
    }

    function getAdminRole(bytes32 role) public view returns (bytes32) {
        return adminRoles[role];
    }

    function _grantRole(bytes32 role, address account) internal {
        if (!roles[account][role]) {
            roles[account][role] = true;
            emit RoleGranted(role, account, msg.sender);
        }
    }

    function _revokeRole(bytes32 role, address account) internal {
        if (roles[account][role]) {
            roles[account][role] = false;
            emit RoleRevoked(role, account, msg.sender);
        }
    }

    function setAdminRole(bytes32 role, bytes32 adminRole) external onlyRole(0x00) {
        adminRoles[role] = adminRole;
    }
}