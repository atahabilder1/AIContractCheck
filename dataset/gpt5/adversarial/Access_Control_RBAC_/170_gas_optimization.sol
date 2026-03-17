// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract RBAC {
    // Roles are represented as bytes32 identifiers. 0x00 is the default admin role.
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    // role => account => isMember
    mapping(bytes32 => mapping(address => bool)) private _roles;
    // role => adminRole (defaults to 0x00 if unset)
    mapping(bytes32 => bytes32) private _admin;

    // Custom errors to save gas
    error AccessDenied(bytes32 role, address account);

    // Events
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleAdminChanged(bytes32 indexed role, bytes32 previousAdminRole, bytes32 newAdminRole);

    constructor() {
        _roles[DEFAULT_ADMIN_ROLE][msg.sender] = true;
        emit RoleGranted(DEFAULT_ADMIN_ROLE, msg.sender, msg.sender);
    }

    // View functions
    function hasRole(bytes32 role, address account) public view returns (bool) {
        return _roles[role][account];
    }

    function getRoleAdmin(bytes32 role) public view returns (bytes32) {
        return _admin[role]; // Defaults to 0x00 (DEFAULT_ADMIN_ROLE) if unset
    }

    // Grant role to an account. Caller must have the role's admin role.
    function grantRole(bytes32 role, address account) external {
        bytes32 admin = _admin[role]; // 0x00 if unset
        if (!_roles[admin][msg.sender]) revert AccessDenied(admin, msg.sender);

        if (!_roles[role][account]) {
            _roles[role][account] = true;
            emit RoleGranted(role, account, msg.sender);
        }
    }

    // Revoke role from an account. Caller must have the role's admin role.
    function revokeRole(bytes32 role, address account) external {
        bytes32 admin = _admin[role]; // 0x00 if unset
        if (!_roles[admin][msg.sender]) revert AccessDenied(admin, msg.sender);

        if (_roles[role][account]) {
            delete _roles[role][account];
            emit RoleRevoked(role, account, msg.sender);
        }
    }

    // Renounce role for the caller.
    function renounceRole(bytes32 role) external {
        address account = msg.sender;
        if (_roles[role][account]) {
            delete _roles[role][account];
            emit RoleRevoked(role, account, msg.sender);
        }
    }

    // Set or change the admin role of a role. Caller must have the current admin role of `role`.
    function setRoleAdmin(bytes32 role, bytes32 newAdmin) external {
        bytes32 currentAdmin = _admin[role]; // 0x00 if unset
        if (!_roles[currentAdmin][msg.sender]) revert AccessDenied(currentAdmin, msg.sender);

        if (currentAdmin != newAdmin) {
            _admin[role] = newAdmin;
            emit RoleAdminChanged(role, currentAdmin, newAdmin);
        }
    }
}