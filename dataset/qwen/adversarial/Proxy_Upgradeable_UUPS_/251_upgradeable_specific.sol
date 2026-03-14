// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

contract MyUpgradeableContract is Initializable, UUPSUpgradeable {
    uint256 public value;

    function initialize() initializer public {
        value = 10;
    }

    function _authorizeUpgrade(address newImplementation) internal override {}
}