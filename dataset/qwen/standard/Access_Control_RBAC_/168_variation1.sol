// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";

contract ExpiringRoles is AccessControl {
    bytes32 public constant ROLE_ADMIN = keccak256("ROLE_ADMIN");
    bytes32 public constant EXPIRING_ROLE = keccak256("EXPIRING_ROLE");

    mapping(address => uint256) private roleExpiry;

    constructor() {
        _grantRole(ROLE_ADMIN, msg.sender);
    }

    modifier onlyRoleAdmin() {
        require(hasRole(ROLE_ADMIN, msg.sender), "ExpiringRoles: caller is not a role admin");
        _;
    }

    modifier onlyValidRole(address account) {
        require(hasRole(EXPIRING_ROLE, account), "ExpiringRoles: account does not have the role");
        require(roleExpiry[account] > block.timestamp, "ExpiringRoles: role has expired");
        _;
    }

    function grantRoleWithExpiry(address account, uint256 duration) public onlyRoleAdmin {
        _grantRole(EXPIRING_ROLE, account);
        roleExpiry[account] = block.timestamp + duration;
    }

    function revokeRole(address account) public onlyRoleAdmin {
        _revokeRole(EXPIRING_ROLE, account);
        delete roleExpiry[account];
    }

    function renewRole(address account, uint256 duration) public onlyRoleAdmin {
        require(hasRole(EXPIRING_ROLE, account), "ExpiringRoles: account does not have the role");
        roleExpiry[account] = block.timestamp + duration;
    }

    function isRoleActive(address account) public view returns (bool) {
        return hasRole(EXPIRING_ROLE, account) && roleExpiry[account] > block.timestamp;
    }

    function getRoleExpiry(address account) public view returns (uint256) {
        return roleExpiry[account];
    }
}