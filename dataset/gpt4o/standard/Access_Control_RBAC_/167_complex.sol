// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract AccessControl {
    using EnumerableSet for EnumerableSet.AddressSet;

    struct RoleData {
        EnumerableSet.AddressSet members;
        bytes32 adminRole;
    }

    mapping(bytes32 => RoleData) private _roles;
    mapping(bytes32 => mapping(address => uint256)) private _roleExpiration;

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;
    uint8 private constant MIN_SIGNATURES = 2;

    struct PendingChange {
        address account;
        bytes32 role;
        uint8 approvals;
    }

    mapping(bytes32 => PendingChange) private _pendingChanges;
    mapping(bytes32 => mapping(address => bool)) private _changeApprovals;

    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender, uint256 expiration);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleAdminChanged(bytes32 indexed role, bytes32 indexed newAdminRole);

    modifier onlyRole(bytes32 role) {
        require(hasRole(role, msg.sender), "AccessControl: sender requires role");
        _;
    }

    function hasRole(bytes32 role, address account) public view returns (bool) {
        return _roles[role].members.contains(account) && (_roleExpiration[role][account] == 0 || _roleExpiration[role][account] > block.timestamp);
    }

    function getRoleAdmin(bytes32 role) public view returns (bytes32) {
        return _roles[role].adminRole;
    }

    function grantRole(bytes32 role, address account, uint256 expiration) public onlyRole(getRoleAdmin(role)) {
        require(!_roles[role].members.contains(account), "AccessControl: account already has role");
        _roles[role].members.add(account);
        _roleExpiration[role][account] = expiration;
        emit RoleGranted(role, account, msg.sender, expiration);
    }

    function revokeRole(bytes32 role, address account) public onlyRole(getRoleAdmin(role)) {
        require(_roles[role].members.contains(account), "AccessControl: account does not have role");
        _roles[role].members.remove(account);
        delete _roleExpiration[role][account];
        emit RoleRevoked(role, account, msg.sender);
    }

    function changeRoleAdmin(bytes32 role, bytes32 newAdminRole) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_pendingChanges[role].approvals >= MIN_SIGNATURES, "AccessControl: not enough approvals");
        _roles[role].adminRole = newAdminRole;
        emit RoleAdminChanged(role, newAdminRole);
        delete _pendingChanges[role];
    }

    function proposeRoleAdminChange(bytes32 role, bytes32 newAdminRole) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(!_changeApprovals[role][msg.sender], "AccessControl: already approved");
        _pendingChanges[role] = PendingChange(msg.sender, newAdminRole, 0);
        _changeApprovals[role][msg.sender] = true;
        _pendingChanges[role].approvals += 1;
    }

    function approveRoleAdminChange(bytes32 role) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_pendingChanges[role].account != address(0), "AccessControl: no pending change");
        require(!_changeApprovals[role][msg.sender], "AccessControl: already approved");
        _changeApprovals[role][msg.sender] = true;
        _pendingChanges[role].approvals += 1;
    }

    function getRoleMemberCount(bytes32 role) public view returns (uint256) {
        return _roles[role].members.length();
    }

    function getRoleMember(bytes32 role, uint256 index) public view returns (address) {
        return _roles[role].members.at(index);
    }
}