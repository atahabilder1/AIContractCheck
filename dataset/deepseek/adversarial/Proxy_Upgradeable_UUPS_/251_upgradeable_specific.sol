// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IProxy {
    function upgradeTo(address newImplementation) external;
    function implementation() external view returns (address);
}

contract Proxy is IProxy {
    address private immutable _implementation;

    constructor(address implementationAddress) {
        _implementation = implementationAddress;
    }

    function implementation() external view override returns (address) {
        return _implementation;
    }

    function upgradeTo(address newImplementation) external override {
        require(msg.sender == address(this), "Only the proxy itself can upgrade");
        require(newImplementation != address(0), "Invalid implementation address");
        _implementation = newImplementation;
    }

    fallback() external payable {
        address impl = _implementation;
        require(impl != address(0), "Implementation contract not set");
        assembly {
            let ptr := mload(0x40)
            calldatacopy(ptr, 0, calldatasize())
            let result := delegatecall(gas(), impl, ptr, calldatasize(), 0, 0)
            let size := returndatasize()
            returndatacopy(ptr, 0, size)
            switch result
            case 0 { revert(ptr, size) }
            default { return(ptr, size) }
        }
    }
}