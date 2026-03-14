// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract AccessControl {
    mapping(address => mapping(string => bool)) private roles;

    event RoleGranted(address indexed account, string indexed role);
    event RoleRevoked(address indexed account, string indexed role);

    modifier onlyRole(string memory role) {
        require(hasRole(msg.sender, role), "AccessControl: Access denied");
        _;
    }

    function grantRole(address account, string memory role) public {
        roles[account][role] = true;
        emit RoleGranted(account, role);
    }

    function revokeRole(address account, string memory role) public {
        roles[account][role] = false;
        emit RoleRevoked(account, role);
    }

    function hasRole(address account, string memory role) public view returns (bool) {
        return roles[account][role];
    }
}