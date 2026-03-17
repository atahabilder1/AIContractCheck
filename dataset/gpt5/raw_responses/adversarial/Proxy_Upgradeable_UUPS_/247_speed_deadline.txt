// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

abstract contract SimpleOwnableUpgradeable is Initializable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        require(msg.sender == _owner, "Not owner");
        _;
    }

    function __SimpleOwnable_init(address initialOwner) internal onlyInitializing {
        require(initialOwner != address(0), "Owner is zero");
        _owner = initialOwner;
        emit OwnershipTransferred(address(0), initialOwner);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "Owner is zero");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

contract HackathonUUPS is Initializable, UUPSUpgradeable, SimpleOwnableUpgradeable {
    uint256 public value;

    event ValueChanged(uint256 value);

    function initialize(uint256 _value) public initializer {
        __SimpleOwnable_init(msg.sender);
        value = _value;
        emit ValueChanged(_value);
    }

    function setValue(uint256 _value) external onlyOwner {
        value = _value;
        emit ValueChanged(_value);
    }

    function increment() external {
        value += 1;
        emit ValueChanged(value);
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}
}

contract HackathonUUPSProxy is ERC1967Proxy {
    constructor(address implementation, bytes memory initData)
        ERC1967Proxy(implementation, initData)
    {}
}