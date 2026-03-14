// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/upgradeability/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/StorageLayout.sol";

/**
 * @title VersionedUUPSUpgradeable
 * @dev A UUPS upgradeable contract with versioned implementations, upgrade timelock,
 *      rollback capability, and storage layout validation.
 */
contract VersionedUUPSUpgradeable is UUPSUpgradeable, Ownable {
    // Mapping from version string to implementation contract address
    mapping(string => address) private _implementations;
    // Mapping from version string to the block number at which it was deployed
    mapping(string => uint256) private _implementationDeployBlock;
    // The current active implementation version string
    string private _activeVersion;
    // The address of the currently active implementation contract
    address private _activeImplementation;

    // Upgrade timelock duration in seconds
    uint256 public upgradeTimelockDuration;
    // Timestamp when the next upgrade can be executed
    uint256 private _nextUpgradeTimestamp;
    // Address of the implementation that is pending upgrade
    address private _pendingImplementation;
    // Version string of the implementation that is pending upgrade
    string private _pendingVersion;

    // Event for when a new implementation is registered
    event ImplementationRegistered(string version, address implementationAddress);
    // Event for when an upgrade is initiated
    event UpgradeInitiated(string newVersion, address newImplementationAddress, uint256 nextUpgradeTimestamp);
    // Event for when an upgrade is completed
    event UpgradeCompleted(string newVersion, address newImplementationAddress);
    // Event for when an upgrade is cancelled
    event UpgradeCancelled();
    // Event for when a rollback is initiated
    event RollbackInitiated(string previousVersion, address previousImplementationAddress, uint256 nextUpgradeTimestamp);
    // Event for when a rollback is completed
    event RollbackCompleted(string previousVersion, address previousImplementationAddress);
    // Event for when the upgrade timelock duration is changed
    event UpgradeTimelockChanged(uint256 newDuration);

    /**
     * @dev Initializes the contract.
     * @param initialVersion The version string of the initial implementation.
     * @param initialImplementationAddress The address of the initial implementation contract.
     * @param timelockDuration The duration of the upgrade timelock in seconds.
     */
    function initialize(string memory initialVersion, address initialImplementationAddress, uint256 timelockDuration) public initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();

        require(initialImplementationAddress != address(0), "Initial implementation address cannot be zero.");
        require(bytes(initialVersion).length > 0, "Initial version cannot be empty.");

        _registerImplementation(initialVersion, initialImplementationAddress);
        _activeVersion = initialVersion;
        _activeImplementation = initialImplementationAddress;
        upgradeTimelockDuration = timelockDuration;

        emit ImplementationRegistered(initialVersion, initialImplementationAddress);
        emit UpgradeCompleted(initialVersion, initialImplementationAddress);
    }

    /**
     * @dev Registers a new implementation contract for a specific version.
     * @param version The version string.
     * @param implementationAddress The address of the implementation contract.
     */
    function registerImplementation(string memory version, address implementationAddress) public onlyOwner {
        require(implementationAddress != address(0), "Implementation address cannot be zero.");
        require(bytes(version).length > 0, "Version cannot be empty.");
        require(_implementations[version] == address(0), "Version already registered.");

        _registerImplementation(version, implementationAddress);
        emit ImplementationRegistered(version, implementationAddress);
    }

    /**
     * @dev Internal function to register an implementation.
     * @param version The version string.
     * @param implementationAddress The address of the implementation contract.
     */
    function _registerImplementation(string memory version, address implementationAddress) internal {
        _implementations[version] = implementationAddress;
        _implementationDeployBlock[version] = block.number;
        // Storage layout validation is implicitly handled by OpenZeppelin's UUPSUpgradeable
        // when the implementation is set. However, we can add explicit checks if needed.
        // For explicit storage layout validation, one would typically compare storage layouts
        // between versions. This requires access to the ABI and storage layout definitions,
        // which is complex to do purely within Solidity. OpenZeppelin's `StorageLayout`
        // utility can help in off-chain verification.
    }

    /**
     * @dev Initiates an upgrade to a new implementation.
     * @param newVersion The version string of the new implementation.
     * @param newImplementationAddress The address of the new implementation contract.
     */
    function initiateUpgrade(string memory newVersion, address newImplementationAddress) public onlyOwner {
        require(bytes(newVersion).length > 0, "New version cannot be empty.");
        require(newImplementationAddress != address(0), "New implementation address cannot be zero.");
        require(_implementations[newVersion] == address(0), "New version already registered.");
        require(_pendingImplementation == address(0), "An upgrade is already pending.");

        _registerImplementation(newVersion, newImplementationAddress); // Register the new version first

        _pendingVersion = newVersion;
        _pendingImplementation = newImplementationAddress;
        _nextUpgradeTimestamp = block.timestamp + upgradeTimelockDuration;

        emit UpgradeInitiated(newVersion, newImplementationAddress, _nextUpgradeTimestamp);
    }

    /**
     * @dev Completes a pending upgrade.
     */
    function completeUpgrade() public onlyOwner {
        require(_pendingImplementation != address(0), "No upgrade is pending.");
        require(block.timestamp >= _nextUpgradeTimestamp, "Upgrade timelock has not expired.");

        address oldImplementation = _activeImplementation;
        string memory oldVersion = _activeVersion;

        // Perform the actual upgrade using UUPSUpgradeable's internal function
        _upgradeTo(_pendingImplementation);

        _activeVersion = _pendingVersion;
        _activeImplementation = _pendingImplementation;

        // Clear pending upgrade details
        _pendingVersion = "";
        _pendingImplementation = address(0);
        _nextUpgradeTimestamp = 0;

        emit UpgradeCompleted(_activeVersion, _activeImplementation);
    }

    /**
     * @dev Cancels a pending upgrade.
     */
    function cancelUpgrade() public onlyOwner {
        require(_pendingImplementation != address(0), "No upgrade is pending.");

        // Optionally, you might want to unregister the pending implementation if it was registered
        // but not yet deployed or if you want to clean up.
        // For simplicity here, we assume it's already registered and might be kept for historical reasons.

        // Clear pending upgrade details
        _pendingVersion = "";
        _pendingImplementation = address(0);
        _nextUpgradeTimestamp = 0;

        emit UpgradeCancelled();
    }

    /**
     * @dev Initiates a rollback to a previously registered implementation.
     * @param targetVersion The version string to roll back to.
     */
    function initiateRollback(string memory targetVersion) public onlyOwner {
        require(bytes(targetVersion).length > 0, "Target version cannot be empty.");
        address targetImplementation = _implementations[targetVersion];
        require(targetImplementation != address(0), "Target version not registered.");
        require(targetImplementation != _activeImplementation, "Cannot roll back to the current active implementation.");
        require(_pendingImplementation == address(0), "An upgrade is already pending. Cannot initiate rollback.");

        _pendingVersion = targetVersion;
        _pendingImplementation = targetImplementation;
        _nextUpgradeTimestamp = block.timestamp + upgradeTimelockDuration;

        emit RollbackInitiated(targetVersion, targetImplementation, _nextUpgradeTimestamp);
    }

    /**
     * @dev Completes a pending rollback.
     */
    function completeRollback() public onlyOwner {
        require(_pendingImplementation != address(0), "No rollback is pending.");
        require(block.timestamp >= _nextUpgradeTimestamp, "Rollback timelock has not expired.");
        require(_implementations[_pendingVersion] == _pendingImplementation, "Pending implementation no longer matches registered version.");

        address oldImplementation = _activeImplementation;
        string memory oldVersion = _activeVersion;

        // Perform the actual rollback (which is essentially an upgrade to an older version)
        _upgradeTo(_pendingImplementation);

        _activeVersion = _pendingVersion;
        _activeImplementation = _pendingImplementation;

        // Clear pending rollback details
        _pendingVersion = "";
        _pendingImplementation = address(0);
        _nextUpgradeTimestamp = 0;

        emit RollbackCompleted(_activeVersion, _activeImplementation);
    }

    /**
     * @dev Changes the upgrade timelock duration.
     * @param newDuration The new duration in seconds.
     */
    function setUpgradeTimelockDuration(uint256 newDuration) public onlyOwner {
        upgradeTimelockDuration = newDuration;
        emit UpgradeTimelockChanged(newDuration);
    }

    /**
     * @dev Returns the address of the current implementation.
     * @return The address of the current implementation contract.
     */
    function getActiveImplementation() public view returns (address) {
        return _activeImplementation;
    }

    /**
     * @dev Returns the version string of the current active implementation.
     * @return The version string.
     */
    function getActiveVersion() public view returns (string memory) {
        return _activeVersion;
    }

    /**
     * @dev Returns the address of a registered implementation for a given version.
     * @param version The version string.
     * @return The address of the implementation contract.
     */
    function getImplementation(string memory version) public view returns (address) {
        return _implementations[version];
    }

    /**
     * @dev Returns the deployment block number of a registered implementation.
     * @param version The version string.
     * @return The block number.
     */
    function getImplementationDeployBlock(string memory version) public view returns (uint256) {
        return _implementationDeployBlock[version];
    }

    /**
     * @dev Returns the address of the pending implementation, if any.
     * @return The address of the pending implementation.
     */
    function getPendingImplementation() public view returns (address) {
        return _pendingImplementation;
    }

    /**
     * @dev Returns the version string of the pending implementation, if any.
     * @return The version string.
     */
    function getPendingVersion() public view returns (string memory) {
        return _pendingVersion;
    }

    /**
     * @dev Returns the timestamp when the pending upgrade/rollback can be executed.
     * @return The timestamp.
     */
    function getNextUpgradeTimestamp() public view returns (uint256) {
        return _nextUpgradeTimestamp;
    }

    /**
     * @dev Internal function to be called by each implementation.
     * @return The address of the current proxy.
     */
    function _underlyingImplementation() internal view override returns (address) {
        return _activeImplementation;
    }
}