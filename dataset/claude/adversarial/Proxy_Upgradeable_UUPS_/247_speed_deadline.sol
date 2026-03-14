// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract UUPSProxy {
    bytes32 private constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
    bytes32 private constant _ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    constructor(address implementation, bytes memory data) {
        _setAdmin(msg.sender);
        _setImplementation(implementation);
        if (data.length > 0) {
            (bool success,) = implementation.delegatecall(data);
            require(success, "Init failed");
        }
    }

    fallback() external payable {
        address impl = _getImplementation();
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

    function _getImplementation() internal view returns (address impl) {
        bytes32 slot = _IMPLEMENTATION_SLOT;
        assembly { impl := sload(slot) }
    }

    function _setImplementation(address impl) internal {
        require(impl.code.length > 0, "Not a contract");
        bytes32 slot = _IMPLEMENTATION_SLOT;
        assembly { sstore(slot, impl) }
    }

    function _setAdmin(address admin) internal {
        bytes32 slot = _ADMIN_SLOT;
        assembly { sstore(slot, admin) }
    }
}

abstract contract UUPSUpgradeable {
    bytes32 private constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    address private _owner;
    bool private _initialized;

    modifier onlyOwner() {
        require(msg.sender == _owner, "Not owner");
        _;
    }

    modifier initializer() {
        require(!_initialized, "Already initialized");
        _initialized = true;
        _;
    }

    function __UUPSUpgradeable_init() internal initializer {
        _owner = msg.sender;
    }

    function owner() public view returns (address) {
        return _owner;
    }

    function upgradeTo(address newImplementation) external onlyOwner {
        require(newImplementation.code.length > 0, "Not a contract");
        bytes32 slot = _IMPLEMENTATION_SLOT;
        assembly { sstore(slot, newImplementation) }
        emit Upgraded(newImplementation);
    }

    function upgradeToAndCall(address newImplementation, bytes memory data) external onlyOwner {
        require(newImplementation.code.length > 0, "Not a contract");
        bytes32 slot = _IMPLEMENTATION_SLOT;
        assembly { sstore(slot, newImplementation) }
        if (data.length > 0) {
            (bool success,) = newImplementation.delegatecall(data);
            require(success, "Upgrade call failed");
        }
        emit Upgraded(newImplementation);
    }

    function getImplementation() external view returns (address impl) {
        bytes32 slot = _IMPLEMENTATION_SLOT;
        assembly { impl := sload(slot) }
    }

    event Upgraded(address indexed implementation);
}

// Example implementation contract V1
contract MyContractV1 is UUPSUpgradeable {
    uint256 public value;

    function initialize() external initializer {
        __UUPSUpgradeable_init();
    }

    function setValue(uint256 _value) external onlyOwner {
        value = _value;
    }

    function getValue() external view returns (uint256) {
        return value;
    }

    function version() external pure returns (string memory) {
        return "v1";
    }
}

// Example implementation contract V2
contract MyContractV2 is UUPSUpgradeable {
    uint256 public value;
    uint256 public multiplier;

    function initialize() external initializer {
        __UUPSUpgradeable_init();
    }

    function setValue(uint256 _value) external onlyOwner {
        value = _value;
    }

    function setMultiplier(uint256 _multiplier) external onlyOwner {
        multiplier = _multiplier;
    }

    function getMultipliedValue() external view returns (uint256) {
        return value * multiplier;
    }

    function version() external pure returns (string memory) {
        return "v2";
    }
}