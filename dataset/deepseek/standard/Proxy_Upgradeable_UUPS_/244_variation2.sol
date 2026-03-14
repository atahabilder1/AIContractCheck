// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IAdmin {
    function upgrade(address newImplementation) external;
    function transferOwnership(address newOwner) external;
    function owner() external view returns (address);
}

contract Admin is IAdmin {
    address private _owner;
    address private _pendingOwner;

    constructor() {
        _owner = msg.sender;
    }

    modifier onlyOwner() {
        require(_owner == msg.sender, "Admin: caller is not the owner");
        _;
    }

    function transferOwnership(address newOwner) external override onlyOwner {
        require(newOwner != address(0), "Admin: new owner is the zero address");
        _pendingOwner = newOwner;
    }

    function acceptOwnership() external {
        require(msg.sender == _pendingOwner, "Admin: caller is not the pending owner");
        _owner = _pendingOwner;
        delete _pendingOwner;
    }

    function owner() external view override returns (address) {
        return _owner;
    }

    function upgrade(address newImplementation) external override onlyOwner {
        // Implementation for upgrading the proxy to a new implementation
    }
}

contract TransparentUpgradeableProxy {
    address private immutable _admin;
    address private _implementation;

    constructor(address admin, address implementation) {
        _admin = admin;
        _implementation = implementation;
    }

    fallback() external payable {
        address impl = _implementation;
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    receive() external payable {}

    function admin() external view returns (address) {
        return _admin;
    }

    function implementation() external view returns (address) {
        return _implementation;
    }

    function upgradeTo(address newImplementation) external {
        require(msg.sender == _admin, "TransparentUpgradeableProxy: caller is not the admin");
        _implementation = newImplementation;
    }
}