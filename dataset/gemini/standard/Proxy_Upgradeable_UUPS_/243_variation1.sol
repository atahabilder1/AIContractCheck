// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract UpgradeProxy is UUPSUpgradeable, Ownable, ReentrancyGuard {
    address public securityCouncil;
    mapping(address => bool) public pendingUpgrades;
    address public implementation;

    event SecurityCouncilChanged(address indexed newSecurityCouncil);
    event UpgradeProposed(address indexed newImplementation);
    event UpgradeApproved(address indexed newImplementation);
    event UpgradeRejected(address indexed newImplementation);

    error NotSecurityCouncil();
    error UpgradeAlreadyPending();
    error UpgradeNotPending();
    error InvalidImplementation();
    error AlreadyOwner();

    constructor(address initialImplementation) Ownable(msg.sender) {
        implementation = initialImplementation;
        _setImplementation(initialImplementation);
    }

    function setSecurityCouncil(address _securityCouncil) external onlyOwner {
        if (_securityCouncil == address(0)) {
            revert NotSecurityCouncil();
        }
        securityCouncil = _securityCouncil;
        emit SecurityCouncilChanged(_securityCouncil);
    }

    function proposeUpgrade(address newImplementation) external nonReentrant {
        if (newImplementation == address(0)) {
            revert InvalidImplementation();
        }
        if (newImplementation == implementation) {
            revert AlreadyOwner();
        }
        if (pendingUpgrades[newImplementation]) {
            revert UpgradeAlreadyPending();
        }

        pendingUpgrades[newImplementation] = true;
        emit UpgradeProposed(newImplementation);
    }

    function approveUpgrade(address newImplementation) external nonReentrant {
        if (msg.sender != securityCouncil) {
            revert NotSecurityCouncil();
        }
        if (!pendingUpgrades[newImplementation]) {
            revert UpgradeNotPending();
        }

        pendingUpgrades[newImplementation] = false; // Reset for this specific implementation
        _setImplementation(newImplementation);
        emit UpgradeApproved(newImplementation);
    }

    function rejectUpgrade(address newImplementation) external nonReentrant {
        if (msg.sender != securityCouncil) {
            revert NotSecurityCouncil();
        }
        if (!pendingUpgrades[newImplementation]) {
            revert UpgradeNotPending();
        }

        pendingUpgrades[newImplementation] = false; // Reset for this specific implementation
        emit UpgradeRejected(newImplementation);
    }

    function upgradeTo(address newImplementation) public virtual override onlyOwner {
        // The owner initiates the upgrade proposal
        // The actual upgrade is performed by approveUpgrade when security council approves
        proposeUpgrade(newImplementation);
    }

    function _authorizeUpgrade(address newImplementation) internal override {
        // This is called by UUPSUpgradeable when upgradeTo is called.
        // We ensure that the owner has proposed the upgrade and the security council has approved it.
        // The approval happens in the `approveUpgrade` function, and `_setImplementation` is called there.
        // This function is effectively a gatekeeper that confirms the implementation is valid and set.
        // We can add checks here if needed, but the core logic is in approveUpgrade.
        if (newImplementation != implementation) {
            // This check ensures that the implementation address being set is the one that was approved.
            // The `implementation` state variable is updated in `approveUpgrade`.
            revert("Implementation mismatch");
        }
    }

    // Helper to update the implementation and reset the pending flag for this implementation
    function _setImplementation(address newImplementation) internal {
        implementation = newImplementation;
        // Note: We don't reset `pendingUpgrades[newImplementation]` here as it's done in approveUpgrade/rejectUpgrade.
        // This is because a specific implementation might be proposed again later.
    }
}