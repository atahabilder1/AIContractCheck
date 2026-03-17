// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract SimpleUUPS is Initializable, UUPSUpgradeable {
    address public admin;
    uint256 private _value;

    event AdminChanged(address indexed previousAdmin, address indexed newAdmin);
    event ValueChanged(uint256 newValue);

    modifier onlyAdmin() {
        require(msg.sender == admin, "UUPS: not admin");
        _;
    }

    function initialize(uint256 initialValue) public initializer {
        __UUPSUpgradeable_init();
        admin = msg.sender;
        _value = initialValue;
        emit ValueChanged(initialValue);
    }

    function setValue(uint256 newValue) external {
        _value = newValue;
        emit ValueChanged(newValue);
    }

    function value() external view returns (uint256) {
        return _value;
    }

    function changeAdmin(address newAdmin) external onlyAdmin {
        require(newAdmin != address(0), "UUPS: zero admin");
        emit AdminChanged(admin, newAdmin);
        admin = newAdmin;
    }

    function _authorizeUpgrade(address) internal override onlyAdmin {}

    uint256[49] private __gap;
}

contract SimpleERC1967Proxy is ERC1967Proxy {
    constructor(address implementation, bytes memory initData)
        ERC1967Proxy(implementation, initData)
    {}
}