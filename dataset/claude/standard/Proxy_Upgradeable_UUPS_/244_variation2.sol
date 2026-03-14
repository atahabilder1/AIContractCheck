// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract ProxyAdmin {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        require(msg.sender == _owner, "ProxyAdmin: caller is not the owner");
        _;
    }

    constructor() {
        _owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "ProxyAdmin: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }

    function getProxyImplementation(TransparentUpgradeableProxy proxy) external view returns (address) {
        (bool success, bytes memory data) = address(proxy).staticcall(
            abi.encodeWithSelector(TransparentUpgradeableProxy.implementation.selector)
        );
        require(success, "ProxyAdmin: call failed");
        return abi.decode(data, (address));
    }

    function getProxyAdmin(TransparentUpgradeableProxy proxy) external view returns (address) {
        (bool success, bytes memory data) = address(proxy).staticcall(
            abi.encodeWithSelector(TransparentUpgradeableProxy.admin.selector)
        );
        require(success, "ProxyAdmin: call failed");
        return abi.decode(data, (address));
    }

    function upgrade(TransparentUpgradeableProxy proxy, address newImplementation) external onlyOwner {
        proxy.upgradeTo(newImplementation);
    }

    function upgradeAndCall(
        TransparentUpgradeableProxy proxy,
        address newImplementation,
        bytes calldata data
    ) external payable onlyOwner {
        proxy.upgradeToAndCall{value: msg.value}(newImplementation, data);
    }

    function changeProxyAdmin(TransparentUpgradeableProxy proxy, address newAdmin) external onlyOwner {
        proxy.changeAdmin(newAdmin);
    }
}

contract TransparentUpgradeableProxy {
    bytes32 private constant _IMPLEMENTATION_SLOT =
        bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1);

    bytes32 private constant _ADMIN_SLOT =
        bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1);

    event Upgraded(address indexed implementation);
    event AdminChanged(address previousAdmin, address newAdmin);

    constructor(address logic, address adminAddr, bytes memory data) payable {
        _setAdmin(adminAddr);
        _setImplementation(logic);
        if (data.length > 0) {
            (bool success, ) = logic.delegatecall(data);
            require(success, "Proxy: initialization failed");
        }
    }

    modifier ifAdmin() {
        if (msg.sender == _getAdmin()) {
            _;
        } else {
            _fallback();
        }
    }

    function admin() external ifAdmin returns (address) {
        return _getAdmin();
    }

    function implementation() external ifAdmin returns (address) {
        return _getImplementation();
    }

    function upgradeTo(address newImplementation) external ifAdmin {
        _setImplementation(newImplementation);
        emit Upgraded(newImplementation);
    }

    function upgradeToAndCall(address newImplementation, bytes calldata data) external payable ifAdmin {
        _setImplementation(newImplementation);
        emit Upgraded(newImplementation);
        if (data.length > 0) {
            (bool success, ) = newImplementation.delegatecall(data);
            require(success, "Proxy: upgrade call failed");
        }
    }

    function changeAdmin(address newAdmin) external ifAdmin {
        require(newAdmin != address(0), "Proxy: new admin is the zero address");
        emit AdminChanged(_getAdmin(), newAdmin);
        _setAdmin(newAdmin);
    }

    fallback() external payable {
        _fallback();
    }

    receive() external payable {
        _fallback();
    }

    function _fallback() private {
        address impl = _getImplementation();
        require(impl != address(0), "Proxy: implementation not set");

        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())

            switch result
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }

    function _getImplementation() private view returns (address impl) {
        bytes32 slot = _IMPLEMENTATION_SLOT;
        assembly {
            impl := sload(slot)
        }
    }

    function _setImplementation(address newImplementation) private {
        require(newImplementation.code.length > 0, "Proxy: implementation is not a contract");
        bytes32 slot = _IMPLEMENTATION_SLOT;
        assembly {
            sstore(slot, newImplementation)
        }
    }

    function _getAdmin() private view returns (address adm) {
        bytes32 slot = _ADMIN_SLOT;
        assembly {
            adm := sload(slot)
        }
    }

    function _setAdmin(address newAdmin) private {
        bytes32 slot = _ADMIN_SLOT;
        assembly {
            sstore(slot, newAdmin)
        }
    }
}

contract ImplementationV1 {
    bool private _initialized;
    address public owner;
    uint256 public value;

    event ValueChanged(uint256 newValue);

    function initialize(address _owner) external {
        require(!_initialized, "Already initialized");
        _initialized = true;
        owner = _owner;
    }

    function setValue(uint256 _value) external {
        require(msg.sender == owner, "Not owner");
        value = _value;
        emit ValueChanged(_value);
    }

    function getValue() external view returns (uint256) {
        return value;
    }

    function version() external pure returns (string memory) {
        return "v1";
    }
}

contract ImplementationV2 {
    bool private _initialized;
    address public owner;
    uint256 public value;
    uint256 public multiplier;

    event ValueChanged(uint256 newValue);
    event MultiplierSet(uint256 newMultiplier);

    function initialize(address _owner) external {
        require(!_initialized, "Already initialized");
        _initialized = true;
        owner = _owner;
    }

    function setValue(uint256 _value) external {
        require(msg.sender == owner, "Not owner");
        value = _value;
        emit ValueChanged(_value);
    }

    function setMultiplier(uint256 _multiplier) external {
        require(msg.sender == owner, "Not owner");
        multiplier = _multiplier;
        emit MultiplierSet(_multiplier);
    }

    function getMultipliedValue() external view returns (uint256) {
        return value * multiplier;
    }

    function getValue() external view returns (uint256) {
        return value;
    }

    function version() external pure returns (string memory) {
        return "v2";
    }
}