// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Library for Address
library Address {
    function isContract(address account) internal view returns (bool) {
        uint256 size;
        assembly { size := extcodesize(account) }
        return size > 0;
    }
}

// Storage Slot Library
library StorageSlot {
    struct AddressSlot { address value; }

    function getAddressSlot(bytes32 slot) internal pure returns (AddressSlot storage r) {
        assembly { r.slot := slot }
    }
}

// Proxy Contract
contract TransparentUpgradeableProxy {
    bytes32 private constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
    bytes32 private constant _ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e01ff8b2c9e3e5f64e5d4c1e0f5f3e0f0;

    constructor(address _logic, address admin_, bytes memory _data) payable {
        assert(_IMPLEMENTATION_SLOT == bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1));
        assert(_ADMIN_SLOT == bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1));

        StorageSlot.getAddressSlot(_ADMIN_SLOT).value = admin_;
        _upgradeToAndCall(_logic, _data, false);
    }

    modifier ifAdmin() {
        require(msg.sender == _admin(), "TransparentUpgradeableProxy: caller is not the admin");
        _;
    }

    function admin() external ifAdmin returns (address admin_) {
        admin_ = _admin();
    }

    function implementation() external ifAdmin returns (address implementation_) {
        implementation_ = _implementation();
    }

    function changeAdmin(address newAdmin) external ifAdmin {
        require(newAdmin != address(0), "TransparentUpgradeableProxy: new admin is the zero address");
        emit AdminChanged(_admin(), newAdmin);
        StorageSlot.getAddressSlot(_ADMIN_SLOT).value = newAdmin;
    }

    function upgradeTo(address newImplementation) external ifAdmin {
        _upgradeToAndCall(newImplementation, bytes(""), false);
    }

    function upgradeToAndCall(address newImplementation, bytes calldata data) external payable ifAdmin {
        _upgradeToAndCall(newImplementation, data, true);
    }

    function _implementation() internal view returns (address impl) {
        return StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value;
    }

    function _admin() internal view returns (address adm) {
        return StorageSlot.getAddressSlot(_ADMIN_SLOT).value;
    }

    function _upgradeToAndCall(
        address newImplementation,
        bytes memory data,
        bool forceCall
    ) internal {
        _setImplementation(newImplementation);
        if (data.length > 0 || forceCall) {
            (bool success, ) = newImplementation.delegatecall(data);
            require(success);
        }
    }

    function _setImplementation(address newImplementation) private {
        require(Address.isContract(newImplementation), "TransparentUpgradeableProxy: new implementation is not a contract");
        StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value = newImplementation;
    }

    fallback () external payable {
        _fallback();
    }

    receive () external payable {
        _fallback();
    }

    function _fallback() internal {
        _delegate(_implementation());
    }

    function _delegate(address implementation) internal {
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), implementation, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    event AdminChanged(address previousAdmin, address newAdmin);
}

// Admin Contract
contract ProxyAdmin {
    function getProxyImplementation(TransparentUpgradeableProxy proxy) public view returns (address) {
        return proxy.implementation();
    }

    function getProxyAdmin(TransparentUpgradeableProxy proxy) public view returns (address) {
        return proxy.admin();
    }

    function upgrade(TransparentUpgradeableProxy proxy, address implementation) public {
        proxy.upgradeTo(implementation);
    }

    function upgradeAndCall(
        TransparentUpgradeableProxy proxy,
        address implementation,
        bytes memory data
    ) public {
        proxy.upgradeToAndCall(implementation, data);
    }
}