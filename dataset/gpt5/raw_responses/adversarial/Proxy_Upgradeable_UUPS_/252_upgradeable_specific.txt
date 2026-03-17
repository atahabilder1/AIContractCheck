// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract UUPSExample is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    uint256 public value;

    constructor() {
        _disableInitializers();
    }

    function initialize(address initialOwner, uint256 initialValue) public initializer {
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();
        value = initialValue;
    }

    function setValue(uint256 newValue) external onlyOwner {
        value = newValue;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}

contract UUPSProxy is ERC1967Proxy {
    constructor(address implementation, bytes memory initData) payable ERC1967Proxy(implementation, initData) {}
}