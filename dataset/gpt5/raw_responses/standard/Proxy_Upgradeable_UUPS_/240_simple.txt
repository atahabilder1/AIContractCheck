// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract MyUUPSUpgradeable is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    uint256 public value;

    constructor() {
        _disableInitializers();
    }

    function initialize(uint256 initialValue) public initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();
        value = initialValue;
    }

    function setValue(uint256 newValue) external onlyOwner {
        value = newValue;
    }

    function version() external pure virtual returns (string memory) {
        return "v1";
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    uint256[50] private __gap;
}

contract MyUUPSUpgradeableV2 is MyUUPSUpgradeable {
    function increment() external onlyOwner {
        value += 1;
    }

    function version() external pure override returns (string memory) {
        return "v2";
    }
}