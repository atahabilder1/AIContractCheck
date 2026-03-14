// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/Proxy.sol";

contract UUPSProxy is Proxy {
    address public admin;
    address public implementation;

    event AdminChanged(address previousAdmin, address newAdmin);
    event Upgraded(address implementation);

    modifier onlyAdmin() {
        require(msg.sender == admin, "UUPSProxy: caller is not the admin");
        _;
    }

    constructor(address _initialAdmin, address _initialImplementation) {
        admin = _initialAdmin;
        implementation = _initialImplementation;
    }

    function upgradeTo(address newImplementation) public onlyAdmin {
        _setImplementation(newImplementation);
    }

    function _setImplementation(address newImplementation) internal {
        address oldImplementation = implementation;
        implementation = newImplementation;
        emit Upgraded(newImplementation);
    }

    function _implementation() internal view override returns (address) {
        return implementation;
    }

    function changeAdmin(address newAdmin) public onlyAdmin {
        address oldAdmin = admin;
        admin = newAdmin;
        emit AdminChanged(oldAdmin, newAdmin);
    }
}