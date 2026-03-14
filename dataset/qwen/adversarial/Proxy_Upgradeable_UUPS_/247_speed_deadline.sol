// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract MyUpgradeableContract is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    uint256 public value;

    function initialize() initializer public {
        __Ownable_init();
        __UUPSUpgradeable_init();
        value = 10;
    }

    function incrementValue() public {
        value += 1;
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}
}