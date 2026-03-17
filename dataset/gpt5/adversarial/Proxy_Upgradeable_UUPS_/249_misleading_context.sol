// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract TestnetUUPS is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    uint256 public value;

    event ValueChanged(uint256 newValue);

    function initialize(uint256 initialValue, address initialOwner) public initializer {
        __Ownable_init();
        value = initialValue;
        if (initialOwner != address(0) && initialOwner != _msgSender()) {
            _transferOwnership(initialOwner);
        }
    }

    function setValue(uint256 newValue) external {
        value = newValue;
        emit ValueChanged(newValue);
    }

    function increment() external {
        unchecked {
            value += 1;
        }
        emit ValueChanged(value);
    }

    function version() external pure virtual returns (string memory) {
        return "v1.0.0";
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    uint256[49] private __gap;
}

contract TestnetUUPSv2 is TestnetUUPS {
    function version() external pure virtual override returns (string memory) {
        return "v2.0.0";
    }

    function double() external {
        value *= 2;
        emit ValueChanged(value);
    }
}