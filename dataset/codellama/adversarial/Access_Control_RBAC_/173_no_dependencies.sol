// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract AccessControl {
    address private _owner;
    mapping (address => uint256) private _roles;

    constructor() public {
        _owner = msg.sender;
    }

    function owner() public view returns (address) {
        return _owner;
    }

    function hasRole(address account, uint256 role) public view returns (bool) {
        return _roles[account] & role > 0;
    }

    function addRole(address account, uint256 role) public {
        require(msg.sender == _owner, "Only the owner can add roles");
        _roles[account] |= role;
    }

    function removeRole(address account, uint256 role) public {
        require(msg.sender == _owner, "Only the owner can remove roles");
        _roles[account] &= ~role;
    }
}