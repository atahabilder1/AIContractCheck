// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC165 {
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

interface IAccessControl {
    event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    function hasRole(bytes32 role, address account) external view returns (bool);
    function getRoleAdmin(bytes32 role) external view returns (bytes32);
    function grantRole(bytes32 role, address account) external;
    function revokeRole(bytes32 role, address account) external;
    function renounceRole(bytes32 role, address account) external;
}

contract AccessControlRBAC is IERC165, IAccessControl {
    struct RoleData {
        mapping(address => bool) members;
        bytes32 adminRole;
    }

    error AccessControlUnauthorizedAccount(address account, bytes32 requiredRole);
    error AccessControlBadConfirmation();

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    mapping(bytes32 => RoleData) private _roles;

    modifier onlyRole(bytes32 role) {
        _checkRole(role, msg.sender);
        _;
    }

    constructor() {
        // DEFAULT_ADMIN_ROLE is its own admin by default (and for all roles)
        _roles[DEFAULT_ADMIN_ROLE].adminRole = DEFAULT_ADMIN_ROLE;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    // IERC165
    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return
            interfaceId == type(IERC165).interfaceId ||
            interfaceId == type(IAccessControl).interfaceId;
    }

    // IAccessControl
    function hasRole(bytes32 role, address account) public view override returns (bool) {
        return _roles[role].members[account];
    }

    function getRoleAdmin(bytes32 role) public view override returns (bytes32) {
        bytes32 admin = _roles[role].adminRole;
        return admin;
    }

    function grantRole(bytes32 role, address account) public override onlyRole(getRoleAdmin(role)) {
        _grantRole(role, account);
    }

    function revokeRole(bytes32 role, address account) public override onlyRole(getRoleAdmin(role)) {
        _revokeRole(role, account);
    }

    function renounceRole(bytes32 role, address account) public override {
        if (account != msg.sender) revert AccessControlBadConfirmation();
        _revokeRole(role, account);
    }

    // Admin management for roles
    function setRoleAdmin(bytes32 role, bytes32 newAdminRole) external onlyRole(getRoleAdmin(role)) {
        bytes32 previousAdminRole = getRoleAdmin(role);
        _roles[role].adminRole = newAdminRole;
        emit RoleAdminChanged(role, previousAdminRole, newAdminRole);
    }

    // Batch helpers (optional)
    function grantRoleBatch(bytes32 role, address[] calldata accounts) external onlyRole(getRoleAdmin(role)) {
        for (uint256 i = 0; i < accounts.length; i++) {
            _grantRole(role, accounts[i]);
        }
    }

    function revokeRoleBatch(bytes32 role, address[] calldata accounts) external onlyRole(getRoleAdmin(role)) {
        for (uint256 i = 0; i < accounts.length; i++) {
            _revokeRole(role, accounts[i]);
        }
    }

    // Internal utilities
    function _checkRole(bytes32 role, address account) internal view {
        if (!hasRole(role, account)) {
            revert AccessControlUnauthorizedAccount(account, role);
        }
    }

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
}