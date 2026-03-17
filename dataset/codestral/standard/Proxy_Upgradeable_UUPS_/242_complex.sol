// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnedUpgradeabilityProxy.sol";
import "@openzeppelin/contracts-upgradeable/utils/StorageSlot.sol";

contract StorageLayout {
    uint256 public version;
}

abstract contract Upgradeable is UUPSUpgradeable, OwnedUpgradeabilityProxy {
    constructor() initializer {}

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {
        super._authorizeUpgrade(newImplementation);
    }

    function _upgradeToAndCallUUPS(address newImplementation, bytes memory data) internal override {
        StorageLayout storageSlot;
        StorageLayout existing = StorageLayout(storageSlot.address);
        require(existing.version <= STORAGE_LAYOUT_VERSION, "Invalid storage layout version");
        super._upgradeToAndCallUUPS(newImplementation, data);
    }
}

contract ImplementationV1 is Upgradeable {
    constructor() Upgradeable() {}

    // Contract logic for V1
}

library Timelock {
    uint256 private constant TIMELOCK_DURATION = 7 days;
    mapping(address => uint256) private timestamps;

    function scheduleUpgrade(UUPSUpgradeable proxy, address newImplementation) public {
        require(proxy.owner() == _msgSender(), "Only the owner can schedule upgrades");
        timestamps[_msgSender()] = block.timestamp + TIMELOCK_DURATION;
        proxy._authorizeUpgrade(newImplementation);
    }

    function executeUpgrade(UUPSUpgradeable proxy, bytes memory data) public {
        require(timestamps[_msgSender()] <= block.timestamp, "Timelock has not expired");
        delete timestamps[_msgSender()];
        proxy._upgradeToAndCallUUPS(_getImplementationAddress(), data);
    }
}