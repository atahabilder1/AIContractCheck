// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract ExpiringAccessControl {
    address public admin;
    uint256 public roleDuration;

    struct Role {
        bool active;
        uint256 expiry;
    }

    mapping(address => Role) private roles;

    event RoleGranted(address indexed account, uint256 expiry);
    event RoleRevoked(address indexed account);
    event RoleRenewed(address indexed account, uint256 newExpiry);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Not an admin");
        _;
    }

    modifier onlyActiveRole() {
        require(roles[msg.sender].active && roles[msg.sender].expiry > block.timestamp, "Role not active or expired");
        _;
    }

    constructor(uint256 _roleDuration) {
        admin = msg.sender;
        roleDuration = _roleDuration;
    }

    function grantRole(address account) external onlyAdmin {
        roles[account] = Role({
            active: true,
            expiry: block.timestamp + roleDuration
        });
        emit RoleGranted(account, roles[account].expiry);
    }

    function revokeRole(address account) external onlyAdmin {
        require(roles[account].active, "Role not active");
        roles[account].active = false;
        emit RoleRevoked(account);
    }

    function renewRole(address account) external onlyAdmin {
        require(roles[account].active, "Role not active");
        roles[account].expiry = block.timestamp + roleDuration;
        emit RoleRenewed(account, roles[account].expiry);
    }

    function hasActiveRole(address account) external view returns (bool) {
        return roles[account].active && roles[account].expiry > block.timestamp;
    }

    function performRestrictedAction() external onlyActiveRole {
        // Restricted action logic here
    }
}