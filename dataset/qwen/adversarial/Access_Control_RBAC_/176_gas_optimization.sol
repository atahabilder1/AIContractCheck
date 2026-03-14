// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract AccessControl {
    mapping(address => uint256) private _roles;

    event RoleGranted(address indexed account, uint256 indexed role);
    event RoleRevoked(address indexed account, uint256 indexed role);

    function _grantRole(address account, uint256 role) internal {
        require((_roles[account] & role) == 0, "AccessControl: account already has role");
        _roles[account] |= role;
        emit RoleGranted(account, role);
    }

    function _revokeRole(address account, uint256 role) internal {
        require((_roles[account] & role) != 0, "AccessControl: account does not have role");
        _roles[account] &= ~role;
        emit RoleRevoked(account, role);
    }

    function hasRole(address account, uint256 role) public view returns (bool) {
        return (_roles[account] & role) != 0;
    }

    modifier onlyRole(uint256 role) {
        require(hasRole(msg.sender, role), "AccessControl: sender must have role");
        _;
    }
}