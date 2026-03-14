// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";

contract MyUpgradeableContract is Initializable, UUPSUpgradeable, ContextUpgradeable {
    uint256 private _value;

    function initialize(uint256 initialValue) public initializer {
        __MyUpgradeableContract_init(initialValue);
    }

    function __MyUpgradeableContract_init(uint256 initialValue) internal onlyInitializing {
        __Context_init_unchained();
        __MyUpgradeableContract_init_unchained(initialValue);
    }

    function __MyUpgradeableContract_init_unchained(uint256 initialValue) internal onlyInitializing {
        _value = initialValue;
    }

    function setValue(uint256 newValue) external {
        _value = newValue;
    }

    function getValue() external view returns (uint256) {
        return _value;
    }

    function _authorizeUpgrade(address) internal override {
        // Simple authorization logic; customize as needed
        require(_msgSender() == address(this), "Unauthorized");
    }
}