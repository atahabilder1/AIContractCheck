// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/access/OwnableUpgradeable.sol";

contract MyUpgradeableProxy is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    uint256 public value;

    function initialize() initializer public {
        __Ownable_init();
    }

    function setValue(uint256 _value) public onlyOwner {
        value = _value;
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyOwner
    {}
}