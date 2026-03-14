// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract RBAC {
    mapping(address => mapping(string => bool)) internal roles;
    address internal _owner;

    modifier onlyOwner() {
        require(msg.sender == _owner, "RBAC: Caller is not the owner");
        _;
    }

    modifier hasRole(string memory _role) {
        require(roles[msg.sender][_role], "RBAC: Caller does not have the required role");
        _;
    }

    constructor() {
        _owner = msg.sender;
        roles[_owner]["admin"] = true; // Owner is also an admin by default
    }

    function addRole(address _user, string memory _role) public onlyOwner {
        roles[_user][_role] = true;
    }

    function removeRole(address _user, string memory _role) public onlyOwner {
        roles[_user][_role] = false;
    }

    function hasRole(address _user, string memory _role) public view returns (bool) {
        return roles[_user][_role];
    }

    function transferOwnership(address _newOwner) public onlyOwner {
        require(_newOwner != address(0), "RBAC: New owner cannot be the zero address");
        roles[_owner]["admin"] = false; // Remove admin role from old owner
        _owner = _newOwner;
        roles[_owner]["admin"] = true; // Grant admin role to new owner
    }
}