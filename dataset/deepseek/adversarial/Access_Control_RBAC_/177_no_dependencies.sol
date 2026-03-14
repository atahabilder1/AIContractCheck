// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract AccessControl {
    // Define a struct to represent a role
    struct Role {
        address[] members;
        mapping(address => bool) isMember;
    }

    // Mapping from role name to role
    mapping(string => Role) public roles;

    // Mapping from address to role name
    mapping(address => string) public userRole;

    // Add a new role
    function addRole(string memory roleName) public {
        require(!hasRole(roleName), "Role already exists");
        roles[roleName] = Role({members: new address[](0), isMember: mapping(address => bool)()});
    }

    // Assign a role to a user
    function assignRole(address user, string memory roleName) public {
        require(hasRole(roleName), "Role does not exist");
        require(userRole[user] == "", "User already has a role");
        roles[roleName].members.push(user);
        roles[roleName].isMember[user] = true;
        userRole[user] = roleName;
    }

    // Remove a role from a user
    function removeRole(address user) public {
        require(userRole[user] != "", "User does not have a role");
        string memory roleName = userRole[user];
        uint256 index = 0;
        for (uint256 i = 0; i < roles[roleName].members.length; i++) {
            if (roles[roleName].members[i] == user) {
                index = i;
                break;
            }
        }
        roles[roleName].members[index] = roles[roleName].members[roles[roleName].members.length - 1];
        roles[roleName].members.pop();
        delete roles[roleName].isMember[user];
        delete userRole[user];
    }

    // Check if a role exists
    function hasRole(string memory roleName) public view returns (bool) {
        return roles[roleName].members.length > 0;
    }

    // Get all members of a role
    function getRoleMembers(string memory roleName) public view returns (address[] memory) {
        return roles[roleName].members;
    }
}