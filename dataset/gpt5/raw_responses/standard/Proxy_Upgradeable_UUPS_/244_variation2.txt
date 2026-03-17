// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Initializable {
    bool private _initialized;

    modifier initializer() {
        require(!_initialized, "Initializable: already initialized");
        _initialized = true;
        _;
    }

    function initialized() public view returns (bool) {
        return _initialized;
    }
}

contract TransparentUpgradeableProxy {
    // EIP-1967 slots:
    // keccak256("eip1967.proxy.implementation") - 1
    bytes32 private constant _IMPLEMENTATION_SLOT =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
    // keccak256("eip1967.proxy.admin") - 1
    bytes32 private constant _ADMIN_SLOT =
        0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    event Upgraded(address indexed implementation);
    event AdminChanged(address previousAdmin, address newAdmin);

    modifier ifAdmin() {
        if (msg.sender == _admin()) {
            _;
        } else {
            _fallback();
        }
    }

    constructor(address _logic, address admin_, bytes memory _data) payable {
        require(_logic != address(0), "Proxy: logic is zero");
        require(admin_ != address(0), "Proxy: admin is zero");
        _setAdmin(admin_);
        _setImplementation(_logic);
        if (_data.length > 0) {
            (bool success, bytes memory returndata) = _logic.delegatecall(_data);
            if (!success) {
                assembly {
                    revert(add(returndata, 0x20), mload(returndata))
                }
            }
        }
    }

    // Admin interface
    function admin() external ifAdmin returns (address) {
        return _admin();
    }

    function implementation() external ifAdmin returns (address) {
        return _implementation();
    }

    function changeAdmin(address newAdmin) external ifAdmin {
        require(newAdmin != address(0), "Proxy: new admin is zero");
        emit AdminChanged(_admin(), newAdmin);
        _setAdmin(newAdmin);
    }

    function upgradeTo(address newImplementation) external ifAdmin {
        _upgradeTo(newImplementation);
    }

    function upgradeToAndCall(address newImplementation, bytes calldata data) external payable ifAdmin {
        _upgradeTo(newImplementation);
        (bool success, bytes memory returndata) = newImplementation.delegatecall(data);
        if (!success) {
            assembly {
                revert(add(returndata, 0x20), mload(returndata))
            }
        }
    }

    // Fallback and receive
    fallback() external payable {
        if (msg.sender == _admin()) {
            revert("TransparentUpgradeableProxy: admin cannot fallback to proxy target");
        }
        _fallback();
    }

    receive() external payable {
        if (msg.sender == _admin()) {
            // Accept ETH from admin without delegating
            return;
        }
        _fallback();
    }

    // Internal mechanics
    function _implementation() internal view returns (address impl) {
        bytes32 slot = _IMPLEMENTATION_SLOT;
        assembly {
            impl := sload(slot)
        }
    }

    function _admin() internal view returns (address adm) {
        bytes32 slot = _ADMIN_SLOT;
        assembly {
            adm := sload(slot)
        }
    }

    function _setImplementation(address newImplementation) private {
        require(newImplementation.code.length > 0, "Proxy: implementation is not a contract");
        bytes32 slot = _IMPLEMENTATION_SLOT;
        assembly {
            sstore(slot, newImplementation)
        }
    }

    function _setAdmin(address newAdmin) private {
        bytes32 slot = _ADMIN_SLOT;
        assembly {
            sstore(slot, newAdmin)
        }
    }

    function _upgradeTo(address newImplementation) internal {
        address current = _implementation();
        require(newImplementation != current, "Proxy: already this implementation");
        _setImplementation(newImplementation);
        emit Upgraded(newImplementation);
    }

    function _delegate(address impl) internal virtual {
        assembly {
            // Copy msg.data. We take full control of memory in this inline assembly
            calldatacopy(0, 0, calldatasize())
            // Delegatecall to the implementation
            let result := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)
            let size := returndatasize()
            returndatacopy(0, 0, size)

            switch result
            case 0 {
                revert(0, size)
            }
            default {
                return(0, size)
            }
        }
    }

    function _fallback() internal {
        _beforeFallback();
        _delegate(_implementation());
    }

    function _beforeFallback() internal virtual {}
}

contract ProxyAdmin {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        require(msg.sender == _owner, "ProxyAdmin: caller is not the owner");
        _;
    }

    constructor(address initialOwner) {
        require(initialOwner != address(0), "ProxyAdmin: zero owner");
        _owner = initialOwner;
        emit OwnershipTransferred(address(0), initialOwner);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "ProxyAdmin: zero new owner");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }

    // Read proxy state
    function getProxyImplementation(TransparentUpgradeableProxy proxy) public view returns (address) {
        // callable only if this ProxyAdmin is the admin of the proxy
        return proxy.implementation();
    }

    function getProxyAdmin(TransparentUpgradeableProxy proxy) public view returns (address) {
        // callable only if this ProxyAdmin is the admin of the proxy
        return proxy.admin();
    }

    // Manage proxy
    function changeProxyAdmin(TransparentUpgradeableProxy proxy, address newAdmin) external onlyOwner {
        proxy.changeAdmin(newAdmin);
    }

    function upgrade(TransparentUpgradeableProxy proxy, address implementation) external onlyOwner {
        proxy.upgradeTo(implementation);
    }

    function upgradeAndCall(
        TransparentUpgradeableProxy proxy,
        address implementation,
        bytes calldata data
    ) external payable onlyOwner {
        proxy.upgradeToAndCall{value: msg.value}(implementation, data);
    }
}

// Example upgradeable implementation V1
contract ExampleV1 is Initializable {
    uint256 public value;
    address public owner;

    event ValueChanged(uint256 value);

    function initialize(uint256 initialValue, address initialOwner) external initializer {
        value = initialValue;
        owner = initialOwner;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "ExampleV1: not owner");
        _;
    }

    function setValue(uint256 newValue) external onlyOwner {
        value = newValue;
        emit ValueChanged(newValue);
    }

    function version() external pure virtual returns (string memory) {
        return "V1";
    }
}

// Example upgradeable implementation V2 (for demonstration)
contract ExampleV2 is ExampleV1 {
    uint256 public extra; // new storage appended

    function increment() external onlyOwner {
        value += 1;
        emit ValueChanged(value);
    }

    function setExtra(uint256 x) external onlyOwner {
        extra = x;
    }

    function version() external pure virtual override returns (string memory) {
        return "V2";
    }
}