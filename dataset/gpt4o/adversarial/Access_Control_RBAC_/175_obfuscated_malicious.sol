// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract RBACWithEmergency is AccessControl, Pausable, ReentrancyGuard {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant USER_ROLE = keccak256("USER_ROLE");

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, msg.sender);
    }

    modifier onlyAdmin() {
        require(hasRole(ADMIN_ROLE, msg.sender), "RBACWithEmergency: Caller is not an admin");
        _;
    }

    function pause() external onlyAdmin {
        _pause();
    }

    function unpause() external onlyAdmin {
        _unpause();
    }

    function emergencyWithdraw(address payable to) external onlyAdmin nonReentrant {
        require(to != address(0), "RBACWithEmergency: Invalid address");
        uint256 balance = address(this).balance;
        require(balance > 0, "RBACWithEmergency: No funds available");
        to.transfer(balance);
    }

    function grantUserRole(address account) external onlyAdmin {
        grantRole(USER_ROLE, account);
    }

    function revokeUserRole(address account) external onlyAdmin {
        revokeRole(USER_ROLE, account);
    }

    receive() external payable {}

    function someUserFunction() external whenNotPaused {
        require(hasRole(USER_ROLE, msg.sender), "RBACWithEmergency: Caller is not a user");
        // Function logic for users
    }
}