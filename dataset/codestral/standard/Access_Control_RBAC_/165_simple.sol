// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract RoleBasedAccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    mapping(bytes32 => mapping(address => bool)) private _roles;

    constructor() {
        // Assign admin role to the deployer
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    function grantRole(bytes32 role, address account) public onlyAdmin(role) {
        _grantRole(role, account);
    }

    function revokeRole(bytes32 role, address account) public onlyAdmin(role) {
        _revokeRole(role, account);
    }

    function hasRole(bytes32 role, address account) public view returns (bool) {
        return _roles[role][account];
    }

    // Modifier to check admin role
    modifier onlyAdmin(bytes32 role) {
        require(_hasRole(ADMIN_ROLE, msg.sender), "Caller is not an admin");
        _;
    }

    function _grantRole(bytes32 role, address account) internal {
        _roles[role][account] = true;
    }

    function _revokeRole(bytes32 role, address account) internal {
        _roles[role][account] = false;
    }

    function _hasRole(bytes32 role, address account) private view returns (bool) {
        return _roles[role][account];
    }
}