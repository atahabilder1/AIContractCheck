// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MyContractV1 is UUPSUpgradeable, Ownable {
    uint256 private _value;

    function initialize(uint256 initialValue) public initializer {
        _value = initialValue;
    }

    function setValue(uint256 newValue) public onlyOwner {
        _value = newValue;
    }

    function getValue() public view returns (uint256) {
        return _value;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}

contract MyContractProxy is ERC1967Proxy, Ownable {
    constructor(address _logic, bytes memory _data) ERC1967Proxy(_logic, _data) Ownable() {}

    function upgradeTo(address newImplementation) external onlyOwner {
        _upgradeToAndCallUUPS(newImplementation, bytes(""), false);
    }

    function upgradeToAndCall(address newImplementation, bytes memory data) external payable onlyOwner {
        _upgradeToAndCallUUPS(newImplementation, data, true);
    }
}