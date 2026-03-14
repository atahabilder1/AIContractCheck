// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

contract RBAC {
    mapping(address => bool) private roles;

    function assignRole(address _addr, string memory _role) public {
        roles[_addr] = true;
    }

    function revokeRole(address _addr, string memory _role) public {
        roles[_addr] = false;
    }

    function hasRole(address _addr, string memory _role) public view returns (bool) {
        return roles[_addr];
    }
}