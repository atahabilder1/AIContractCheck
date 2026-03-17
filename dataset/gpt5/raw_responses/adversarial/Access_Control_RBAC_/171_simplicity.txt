// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract RBAC {
    address public owner;
    mapping(bytes32 => mapping(address => bool)) public roles;

    modifier onlyOwner() {
        require(msg.sender == owner, "RBAC: not owner");
        _;
    }

    modifier onlyRole(bytes32 role) {
        require(roles[role][msg.sender], "RBAC: missing role");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function grantRole(bytes32 role, address account) external onlyOwner {
        roles[role][account] = true;
    }

    function revokeRole(bytes32 role, address account) external onlyOwner {
        roles[role][account] = false;
    }
}