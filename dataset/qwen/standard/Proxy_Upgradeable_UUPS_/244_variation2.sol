// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts-upgradeable/proxy/transparent/ProxyAdmin.sol";

contract MyContract is Initializable, OwnableUpgradeable {
    uint256 public value;

    function initialize(uint256 _initialValue) public initializer {
        __Ownable_init();
        value = _initialValue;
    }

    function setValue(uint256 _newValue) public onlyOwner {
        value = _newValue;
    }
}

contract MyContractAdmin is OwnableUpgradeable {
    ProxyAdmin public proxyAdmin;

    function initialize() public initializer {
        __Ownable_init();
        proxyAdmin = new ProxyAdmin();
    }

    function upgrade(address proxy, address newImplementation) public onlyOwner {
        proxyAdmin.upgrade(TransparentUpgradeableProxy(payable(proxy)), newImplementation);
    }
}