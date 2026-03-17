// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/presets/ERC20PresetMinterPauserUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract MyToken is Initializable, ERC20PresetMinterPauserUpgradeable, OwnableUpgradeable {
    uint8 private __gap;

    constructor() initializer {}

    function initialize(string memory _name, string memory _symbol, address _upgrader) public initializer {
        __ERC20_init(_name, _symbol);
        __Ownable_init();
        transferOwnership(_upgrader);
    }

    function upgradeTo(address newImplementation) public onlyOwner {
        _upgradeTo(newImplementation);
    }
}