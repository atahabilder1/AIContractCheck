// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract RBAC {
    mapping(address => uint256) private _roles;

    uint256 constant ROLE_NONE = 0;
    uint256 constant ROLE_ADMIN = 1 << 0;
    uint256 constant ROLE_MINTER = 1 << 1;

    address private _owner;

    modifier onlyAdmin() {
        require(_roles[msg.sender] & ROLE_ADMIN != 0, "RBAC: Caller is not an admin");
        _;
    }

    modifier onlyMinter() {
        require(_roles[msg.sender] & ROLE_MINTER != 0, "RBAC: Caller is not a minter");
        _;
    }

    constructor() {
        _owner = msg.sender;
        _roles[msg.sender] = ROLE_ADMIN | ROLE_MINTER; // Owner is both admin and minter
    }

    function getRoles(address account) public view returns (uint256) {
        return _roles[account];
    }

    function addRole(address account, uint256 role) public onlyAdmin {
        require(role == ROLE_ADMIN || role == ROLE_MINTER, "RBAC: Invalid role");
        _roles[account] |= role;
    }

    function removeRole(address account, uint256 role) public onlyAdmin {
        require(role == ROLE_ADMIN || role == ROLE_MINTER, "RBAC: Invalid role");
        _roles[account] &= ~role;
    }

    function renounceOwnership() public {
        require(msg.sender == _owner, "RBAC: Caller is not the owner");
        _owner = address(0);
    }

    function transferOwnership(address newOwner) public {
        require(msg.sender == _owner, "RBAC: Caller is not the owner");
        _owner = newOwner;
    }
}