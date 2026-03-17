// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IProxiable {
    function proxiableUUID() external view returns (bytes32);
}

contract UUPSProxy {
    // EIP-1967 implementation slot = bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1)
    bytes32 private constant IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    constructor(address _logic, bytes memory _data) payable {
        assembly {
            sstore(IMPLEMENTATION_SLOT, _logic)
        }
        if (_data.length > 0) {
            (bool ok, ) = _logic.delegatecall(_data);
            require(ok);
        }
    }

    fallback() external payable {
        assembly {
            let impl := sload(IMPLEMENTATION_SLOT)
            calldatacopy(0, 0, calldatasize())
            let res := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)
            let size := returndatasize()
            returndatacopy(0, 0, size)
            switch res
            case 0 { revert(0, size) }
            default { return(0, size) }
        }
    }

    receive() external payable {
        assembly {
            let impl := sload(IMPLEMENTATION_SLOT)
            calldatacopy(0, 0, calldatasize())
            let res := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)
            let size := returndatasize()
            returndatacopy(0, 0, size)
            switch res
            case 0 { revert(0, size) }
            default { return(0, size) }
        }
    }
}

contract UUPSImplementationV1 is IProxiable {
    address public owner;
    uint256 public value;
    bool private _initialized;

    // EIP-1967 implementation slot = bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1)
    bytes32 private constant IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    function initialize(address _owner, uint256 _value) external {
        require(!_initialized, "initialized");
        owner = _owner;
        value = _value;
        _initialized = true;
    }

    function setValue(uint256 v) external onlyOwner {
        value = v;
    }

    function upgradeTo(address newImplementation) external onlyOwner {
        require(IProxiable(newImplementation).proxiableUUID() == IMPLEMENTATION_SLOT, "not uups");
        assembly {
            sstore(IMPLEMENTATION_SLOT, newImplementation)
        }
    }

    function proxiableUUID() external pure returns (bytes32) {
        return IMPLEMENTATION_SLOT;
    }
}