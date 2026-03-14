// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract DualApprovalUUPSProxy is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    address public securityCouncil;

    struct UpgradeProposal {
        address newImplementation;
        bool ownerApproved;
        bool councilApproved;
    }

    UpgradeProposal public pendingUpgrade;

    event UpgradeProposed(address indexed newImplementation, address indexed proposer);
    event UpgradeApproved(address indexed newImplementation, address indexed approver);
    event UpgradeExecuted(address indexed newImplementation);
    event UpgradeCancelled(address indexed newImplementation);
    event SecurityCouncilTransferred(address indexed oldCouncil, address indexed newCouncil);

    error NotOwnerOrCouncil();
    error NoUpgradePending();
    error UpgradeNotFullyApproved();
    error AlreadyApproved();
    error ZeroAddress();
    error NotSecurityCouncil();
    error ImplementationMismatch();

    modifier onlyOwnerOrCouncil() {
        if (msg.sender != owner() && msg.sender != securityCouncil) revert NotOwnerOrCouncil();
        _;
    }

    modifier onlySecurityCouncil() {
        if (msg.sender != securityCouncil) revert NotSecurityCouncil();
        _;
    }

    function initialize(address _owner, address _securityCouncil) external initializer {
        if (_owner == address(0) || _securityCouncil == address(0)) revert ZeroAddress();
        __Ownable_init(_owner);
        __UUPSUpgradeable_init();
        securityCouncil = _securityCouncil;
    }

    function proposeUpgrade(address newImplementation) external onlyOwnerOrCouncil {
        if (newImplementation == address(0)) revert ZeroAddress();

        pendingUpgrade = UpgradeProposal({
            newImplementation: newImplementation,
            ownerApproved: msg.sender == owner(),
            councilApproved: msg.sender == securityCouncil
        });

        emit UpgradeProposed(newImplementation, msg.sender);
    }

    function approveUpgrade(address newImplementation) external onlyOwnerOrCouncil {
        if (pendingUpgrade.newImplementation == address(0)) revert NoUpgradePending();
        if (pendingUpgrade.newImplementation != newImplementation) revert ImplementationMismatch();

        if (msg.sender == owner()) {
            if (pendingUpgrade.ownerApproved) revert AlreadyApproved();
            pendingUpgrade.ownerApproved = true;
        } else {
            if (pendingUpgrade.councilApproved) revert AlreadyApproved();
            pendingUpgrade.councilApproved = true;
        }

        emit UpgradeApproved(newImplementation, msg.sender);
    }

    function executeUpgrade() external onlyOwnerOrCouncil {
        if (pendingUpgrade.newImplementation == address(0)) revert NoUpgradePending();
        if (!pendingUpgrade.ownerApproved || !pendingUpgrade.councilApproved) revert UpgradeNotFullyApproved();

        address newImpl = pendingUpgrade.newImplementation;
        delete pendingUpgrade;

        upgradeToAndCall(newImpl, "");
        emit UpgradeExecuted(newImpl);
    }

    function cancelUpgrade() external onlyOwnerOrCouncil {
        if (pendingUpgrade.newImplementation == address(0)) revert NoUpgradePending();
        address cancelled = pendingUpgrade.newImplementation;
        delete pendingUpgrade;
        emit UpgradeCancelled(cancelled);
    }

    function transferSecurityCouncil(address newCouncil) external onlySecurityCouncil {
        if (newCouncil == address(0)) revert ZeroAddress();
        address oldCouncil = securityCouncil;
        securityCouncil = newCouncil;
        emit SecurityCouncilTransferred(oldCouncil, newCouncil);
    }

    function _authorizeUpgrade(address newImplementation) internal view override {
        if (pendingUpgrade.newImplementation != newImplementation) revert ImplementationMismatch();
        if (!pendingUpgrade.ownerApproved || !pendingUpgrade.councilApproved) revert UpgradeNotFullyApproved();
    }
}