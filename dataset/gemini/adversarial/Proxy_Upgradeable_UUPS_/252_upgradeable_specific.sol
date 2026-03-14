// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MyContract is UUPSUpgradeable, Ownable {
    string public value;

    function initialize(string memory _value) public initializer {
        value = _value;
    }

    function setValue(string memory _newValue) public {
        value = _newValue;
    }

    function upgradeTo(address newImplementation) public onlyOwner {
        _upgradeToAndCall(newImplementation, "");
    }
}