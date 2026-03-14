// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract AccessControl {
    address private admin;
    mapping(address => Role) private roles;
    mapping(address => uint256) private expirations;

    struct Role {
        string name;
        uint256 expiration;
    }

    event RoleAssigned(address indexed account, string role, uint256 expiration);
    event RoleExpired(address indexed account, string role);

    constructor(address _admin) {
        admin = _admin;
    }

    function assignRole(address account, string memory role, uint256 duration) public {
        require(msg.sender == admin, "Only the admin can assign roles");
        require(roles[account].name == "", "Account already has a role");

        roles[account] = Role(role, now + duration);
        expirations[account] = now + duration;

        emit RoleAssigned(account, role, duration);
    }

    function renewRole(address account, string memory role, uint256 duration) public {
        require(msg.sender == admin, "Only the admin can renew roles");
        require(roles[account].name == role, "Account does not have the specified role");

        roles[account].expiration = now + duration;
        expirations[account] = now + duration;

        emit RoleAssigned(account, role, duration);
    }

    function revokeRole(address account, string memory role) public {
        require(msg.sender == admin, "Only the admin can revoke roles");
        require(roles[account].name == role, "Account does not have the specified role");

        delete roles[account];
        delete expirations[account];

        emit RoleExpired(account, role);
    }

    function hasRole(address account, string memory role) public view returns (bool) {
        return roles[account].name == role;
    }

    function getRoleExpiration(address account, string memory role) public view returns (uint256) {
        return expirations[account];
    }
}