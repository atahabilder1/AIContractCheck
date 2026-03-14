// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract RBAC {
    mapping(address => mapping(bytes32 => bool)) private _roles;
    address private _owner;

    event RoleGranted(address indexed account, bytes32 indexed role);
    event RoleRevoked(address indexed account, bytes32 indexed role);

    modifier onlyOwner() {
        require(msg.sender == _owner, "RBAC: Caller is not the owner");
        _;
    }

    modifier hasRole(bytes32 role) {
        require(_roles[msg.sender][role], "RBAC: Caller does not have the role");
        _;
    }

    constructor() {
        _owner = msg.sender;
    }

    function grantRole(bytes32 role, address account) public onlyOwner {
        _roles[account][role] = true;
        emit RoleGranted(account, role);
    }

    function revokeRole(bytes32 role, address account) public onlyOwner {
        _roles[account][role] = false;
        emit RoleRevoked(account, role);
    }

    function hasRole(bytes32 role, address account) public view returns (bool) {
        return _roles[account][role];
    }

    function renounceRole(bytes32 role, address account) public {
        require(msg.sender == account, "RBAC: Caller cannot renounce role for another account");
        _roles[account][role] = false;
        emit RoleRevoked(account, role);
    }

    function transferOwnership(address newOwner) public onlyOwner {
        _owner = newOwner;
    }

    function owner() public view returns (address) {
        return _owner;
    }
}