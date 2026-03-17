// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract RoleAccessControl {
    struct Role {
        address user;
        uint256 expirationTime;
    }

    mapping(bytes32 => Role) public roles;

    event RoleExpired(bytes32 role, address indexed user);
    event RoleRenewed(bytes32 role, address indexed user, uint256 newExpirationTime);

    modifier onlyAdmin() {
        require(msg.sender == 0xADMIN_ADDRESS, "Only the admin can perform this action.");
        _;
    }

    function grantRole(bytes32 role, address user, uint256 duration) public onlyAdmin {
        roles[role] = Role({user: user, expirationTime: block.timestamp + duration});
    }

    function renewRole(bytes32 role) public {
        require(roles[role].user == msg.sender, "You do not have this role.");
        require(block.timestamp < roles[role].expirationTime, "This role has already expired.");

        roles[role].expirationTime = block.timestamp + 365 days; // Set the new expiration time (1 year)
        emit RoleRenewed(role, msg.sender, roles[role].expirationTime);
    }

    function checkRoleExpiration(bytes32 role) public view returns (bool) {
        return block.timestamp > roles[role].expirationTime;
    }
}