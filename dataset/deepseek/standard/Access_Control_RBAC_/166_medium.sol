// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract RBAC {
    struct Role {
        string name;
        bytes32 roleHash;
        uint256 roleId;
        bool isDefault;
    }

    mapping(uint256 => Role) public roles;
    uint256 public roleCount;

    mapping(address => uint256) public userRoles;
    mapping(uint256 => mapping(uint256 => bool)) public roleGrants;

    event RoleGranted(address indexed user, uint256 indexed roleId);
    event RoleRevoked(address indexed user, uint256 indexed roleId);

    modifier onlyRole(uint256 roleId) {
        require(roleGrants[roleId][userRoles[msg.sender]] || userRoles[msg.sender] == roleId, "RBAC: insufficient permissions");
        _;
    }

    function addRole(string memory name, bool isDefault) public {
        roleCount++;
        roles[roleCount] = Role(name, keccak256(abi.encodePacked(name)), roleCount, isDefault);
        if (isDefault) {
            userRoles[msg.sender] = roleCount;
            emit RoleGranted(msg.sender, roleCount);
        }
    }

    function grantRole(address user, uint256 roleId) public {
        require(roleGrants[roleId][userRoles[msg.sender]], "RBAC: role not granted");
        userRoles[user] = roleId;
        emit RoleGranted(user, roleId);
    }

    function revokeRole(address user, uint256 roleId) public {
        require(roleGrants[roleId][userRoles[msg.sender]], "RBAC: role not granted");
        userRoles[user] = 0;
        emit RoleRevoked(user, roleId);
    }
}