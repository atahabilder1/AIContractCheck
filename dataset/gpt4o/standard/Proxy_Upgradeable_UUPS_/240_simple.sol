// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract MyUpgradeableContract is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    uint256 private _value;

    function initialize(uint256 initialValue) public initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();
        _value = initialValue;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function setValue(uint256 newValue) external onlyOwner {
        _value = newValue;
    }

    function getValue() external view returns (uint256) {
        return _value;
    }
}