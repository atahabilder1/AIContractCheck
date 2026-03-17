// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract RBAC {
    // Roles
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    // role => (account => hasRole)
    mapping(bytes32 => mapping(address => bool)) private _roles;
    // role => adminRole
    mapping(bytes32 => bytes32) private _roleAdmin;

    // Errors
    error AccessControlUnauthorizedAccount(address account, bytes32 neededRole);
    error AccessControlBadSelfRenounce();

    // Events
    event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    modifier onlyRole(bytes32 role) {
        if (!_roles[role][msg.sender]) revert AccessControlUnauthorizedAccount(msg.sender, role);
        _;
    }

    constructor() {
        // Bootstrap admin
        _roles[DEFAULT_ADMIN_ROLE][msg.sender] = true;
        emit RoleGranted(DEFAULT_ADMIN_ROLE, msg.sender, msg.sender);
    }

    // Views
    function hasRole(bytes32 role, address account) external view returns (bool) {
        return _roles[role][account];
    }

    function getRoleAdmin(bytes32 role) external view returns (bytes32) {
        bytes32 admin = _roleAdmin[role];
        return admin == bytes32(0) ? DEFAULT_ADMIN_ROLE : admin;
    }

    // Admin ops
    function setRoleAdmin(bytes32 role, bytes32 newAdminRole) external onlyRole(DEFAULT_ADMIN_ROLE) {
        bytes32 prev = _roleAdmin[role];
        if (prev == bytes32(0)) prev = DEFAULT_ADMIN_ROLE;
        if (prev == newAdminRole) return;
        _roleAdmin[role] = newAdminRole;
        emit RoleAdminChanged(role, prev, newAdminRole);
    }

    // Mutations
    function grantRole(bytes32 role, address account) external {
        bytes32 admin = _roleAdmin[role];
        if (admin == bytes32(0)) admin = DEFAULT_ADMIN_ROLE;
        if (!_roles[admin][msg.sender]) revert AccessControlUnauthorizedAccount(msg.sender, admin);
        if (_roles[role][account]) return;
        _roles[role][account] = true;
        emit RoleGranted(role, account, msg.sender);
    }

    function revokeRole(bytes32 role, address account) external {
        bytes32 admin = _roleAdmin[role];
        if (admin == bytes32(0)) admin = DEFAULT_ADMIN_ROLE;
        if (!_roles[admin][msg.sender]) revert AccessControlUnauthorizedAccount(msg.sender, admin);
        if (!_roles[role][account]) return;
        _roles[role][account] = false;
        emit RoleRevoked(role, account, msg.sender);
    }

    function renounceRole(bytes32 role, address account) external {
        if (account != msg.sender) revert AccessControlBadSelfRenounce();
        if (!_roles[role][account]) return;
        _roles[role][account] = false;
        emit RoleRevoked(role, account, msg.sender);
    }
}