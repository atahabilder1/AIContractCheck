// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract RBAC {
    // Custom errors
    error AccessControlUnauthorizedAccount(address account, bytes32 role);
    error AccessControlBadConfirmation();

    // Events
    event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    // Storage
    struct RoleData {
        mapping(address => bool) members;
        bytes32 adminRole;
    }

    mapping(bytes32 => RoleData) private _roles;

    // Default admin role: 0x00
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    // Constructor: assign deployer as default admin
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        // DEFAULT_ADMIN_ROLE is its own admin by default via zero value
        _roles[DEFAULT_ADMIN_ROLE].adminRole = DEFAULT_ADMIN_ROLE;
    }

    // Modifiers
    modifier onlyRole(bytes32 role) {
        if (!hasRole(role, msg.sender)) {
            revert AccessControlUnauthorizedAccount(msg.sender, role);
        }
        _;
    }

    // Views
    function hasRole(bytes32 role, address account) public view returns (bool) {
        return _roles[role].members[account];
    }

    function getRoleAdmin(bytes32 role) public view returns (bytes32) {
        bytes32 admin = _roles[role].adminRole;
        return admin;
    }

    // Role management
    function grantRole(bytes32 role, address account) public onlyRole(getRoleAdmin(role)) {
        _grantRole(role, account);
    }

    function revokeRole(bytes32 role, address account) public onlyRole(getRoleAdmin(role)) {
        _revokeRole(role, account);
    }

    function renounceRole(bytes32 role, address account) public {
        if (account != msg.sender) revert AccessControlBadConfirmation();
        _revokeRole(role, account);
    }

    function setRoleAdmin(bytes32 role, bytes32 adminRole) public onlyRole(DEFAULT_ADMIN_ROLE) {
        bytes32 previousAdminRole = getRoleAdmin(role);
        _roles[role].adminRole = adminRole;
        emit RoleAdminChanged(role, previousAdminRole, adminRole);
    }

    // Internal helpers
    function _grantRole(bytes32 role, address account) internal {
        if (!_roles[role].members[account]) {
            _roles[role].members[account] = true;
            emit RoleGranted(role, account, msg.sender);
        }
    }

    function _revokeRole(bytes32 role, address account) internal {
        if (_roles[role].members[account]) {
            _roles[role].members[account] = false;
            emit RoleRevoked(role, account, msg.sender);
        }
    }

    // Optional helper for initialization in derived contracts
    function _setupRole(bytes32 role, address account) internal {
        _grantRole(role, account);
    }
}