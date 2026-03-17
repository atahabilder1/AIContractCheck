// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract TestnetAccessControl {
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    mapping(bytes32 => mapping(address => bool)) private _roles;
    mapping(bytes32 => bytes32) private _roleAdmins;

    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleAdminChanged(bytes32 indexed role, bytes32 previousAdminRole, bytes32 newAdminRole);

    constructor() {
        _roles[DEFAULT_ADMIN_ROLE][msg.sender] = true;
        _roleAdmins[DEFAULT_ADMIN_ROLE] = DEFAULT_ADMIN_ROLE;
    }

    modifier onlyRole(bytes32 role) {
        require(hasRole(role, msg.sender), "AccessControl: missing required role");
        _;
    }

    function hasRole(bytes32 role, address account) public view returns (bool) {
        return _roles[role][account];
    }

    function getRoleAdmin(bytes32 role) public view returns (bytes32) {
        return _roleAdmins[role] == bytes32(0) ? DEFAULT_ADMIN_ROLE : _roleAdmins[role];
    }

    function setRoleAdmin(bytes32 role, bytes32 adminRole) external onlyRole(DEFAULT_ADMIN_ROLE) {
        bytes32 previous = getRoleAdmin(role);
        _roleAdmins[role] = adminRole;
        emit RoleAdminChanged(role, previous, adminRole);
    }

    function grantRole(bytes32 role, address account) public onlyRole(getRoleAdmin(role)) {
        if (!_roles[role][account]) {
            _roles[role][account] = true;
            emit RoleGranted(role, account, msg.sender);
        }
    }

    function revokeRole(bytes32 role, address account) public onlyRole(getRoleAdmin(role)) {
        if (_roles[role][account]) {
            _roles[role][account] = false;
            emit RoleRevoked(role, account, msg.sender);
        }
    }

    function renounceRole(bytes32 role, address account) external {
        require(account == msg.sender, "AccessControl: can only renounce for self");
        if (_roles[role][account]) {
            _roles[role][account] = false;
            emit RoleRevoked(role, account, msg.sender);
        }
    }

    function transferDefaultAdmin(address newAdmin) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newAdmin != address(0), "AccessControl: new admin is zero address");
        if (!_roles[DEFAULT_ADMIN_ROLE][newAdmin]) {
            _roles[DEFAULT_ADMIN_ROLE][newAdmin] = true;
            emit RoleGranted(DEFAULT_ADMIN_ROLE, newAdmin, msg.sender);
        }
        if (_roles[DEFAULT_ADMIN_ROLE][msg.sender]) {
            _roles[DEFAULT_ADMIN_ROLE][msg.sender] = false;
            emit RoleRevoked(DEFAULT_ADMIN_ROLE, msg.sender, msg.sender);
        }
    }
}