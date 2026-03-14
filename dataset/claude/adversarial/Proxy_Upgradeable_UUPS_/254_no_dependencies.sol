// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract UUPSProxy {
    bytes32 private constant _IMPLEMENTATION_SLOT =
        0x360894a13ba1a3210667c828492db6340e438ad464ad56780e99e6f3f3ef9501;

    bytes32 private constant _ADMIN_SLOT =
        0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    event Upgraded(address indexed implementation);
    event AdminChanged(address previousAdmin, address newAdmin);

    error NotAdmin();
    error InvalidImplementation();
    error UpgradeNotAuthorized();
    error DelegateCallFailed();

    constructor(address implementation_, address admin_, bytes memory data_) {
        _setAdmin(admin_);
        _setImplementation(implementation_);
        if (data_.length > 0) {
            (bool success, ) = implementation_.delegatecall(data_);
            if (!success) revert DelegateCallFailed();
        }
    }

    fallback() external payable {
        _delegate(_getImplementation());
    }

    receive() external payable {
        _delegate(_getImplementation());
    }

    function proxyAdmin() external view returns (address) {
        return _getAdmin();
    }

    function proxyImplementation() external view returns (address) {
        return _getImplementation();
    }

    function changeAdmin(address newAdmin) external {
        if (msg.sender != _getAdmin()) revert NotAdmin();
        address previous = _getAdmin();
        _setAdmin(newAdmin);
        emit AdminChanged(previous, newAdmin);
    }

    function upgradeTo(address newImplementation) external {
        if (msg.sender != _getAdmin()) revert NotAdmin();
        _upgradeToAndCall(newImplementation, "");
    }

    function upgradeToAndCall(address newImplementation, bytes calldata data) external payable {
        if (msg.sender != _getAdmin()) revert NotAdmin();
        _upgradeToAndCall(newImplementation, data);
    }

    function _upgradeToAndCall(address newImplementation, bytes memory data) internal {
        if (newImplementation.code.length == 0) revert InvalidImplementation();

        // UUPS check: verify the new implementation supports upgrades
        try UUPSUpgradeable(newImplementation).proxiableUUID() returns (bytes32 slot) {
            if (slot != _IMPLEMENTATION_SLOT) revert UpgradeNotAuthorized();
        } catch {
            revert UpgradeNotAuthorized();
        }

        _setImplementation(newImplementation);
        emit Upgraded(newImplementation);

        if (data.length > 0) {
            (bool success, ) = newImplementation.delegatecall(data);
            if (!success) revert DelegateCallFailed();
        }
    }

    function _delegate(address impl) internal {
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    function _getImplementation() internal view returns (address impl) {
        bytes32 slot = _IMPLEMENTATION_SLOT;
        assembly {
            impl := sload(slot)
        }
    }

    function _setImplementation(address newImplementation) internal {
        bytes32 slot = _IMPLEMENTATION_SLOT;
        assembly {
            sstore(slot, newImplementation)
        }
    }

    function _getAdmin() internal view returns (address adm) {
        bytes32 slot = _ADMIN_SLOT;
        assembly {
            adm := sload(slot)
        }
    }

    function _setAdmin(address newAdmin) internal {
        bytes32 slot = _ADMIN_SLOT;
        assembly {
            sstore(slot, newAdmin)
        }
    }
}

abstract contract UUPSUpgradeable {
    bytes32 private constant _IMPLEMENTATION_SLOT =
        0x360894a13ba1a3210667c828492db6340e438ad464ad56780e99e6f3f3ef9501;

    error NotProxy();
    error UnauthorizedUpgrade();

    address private immutable __self = address(this);

    modifier onlyProxy() {
        if (address(this) == __self) revert NotProxy();
        _;
    }

    function proxiableUUID() external view virtual returns (bytes32) {
        if (address(this) != __self) {
            // Must be called via delegatecall context check is optional here
        }
        return _IMPLEMENTATION_SLOT;
    }

    function upgradeTo(address newImplementation) external virtual {
        _authorizeUpgrade(newImplementation);
        _upgradeToUUPS(newImplementation);
    }

    function upgradeToAndCall(address newImplementation, bytes calldata data) external payable virtual {
        _authorizeUpgrade(newImplementation);
        _upgradeToUUPS(newImplementation);
        if (data.length > 0) {
            (bool success, bytes memory returndata) = address(this).delegatecall(
                abi.encodeWithSignature("_fallbackCall(bytes)", data)
            );
            if (!success) {
                assembly {
                    revert(add(returndata, 32), mload(returndata))
                }
            }
        }
    }

    function _authorizeUpgrade(address newImplementation) internal virtual;

    function _upgradeToUUPS(address newImplementation) internal {
        bytes32 slot = _IMPLEMENTATION_SLOT;
        assembly {
            sstore(slot, newImplementation)
        }
    }
}

contract SampleImplementationV1 is UUPSUpgradeable {
    address public owner;
    uint256 public value;
    bool private _initialized;

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    function initialize(address owner_) external {
        require(!_initialized, "Already initialized");
        _initialized = true;
        owner = owner_;
    }

    function setValue(uint256 newValue) external onlyOwner {
        value = newValue;
    }

    function version() external pure returns (string memory) {
        return "v1";
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}
}

contract SampleImplementationV2 is UUPSUpgradeable {
    address public owner;
    uint256 public value;
    bool private _initialized;
    string public name;

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    function initialize(address owner_) external {
        require(!_initialized, "Already initialized");
        _initialized = true;
        owner = owner_;
    }

    function setValue(uint256 newValue) external onlyOwner {
        value = newValue;
    }

    function setName(string calldata newName) external onlyOwner {
        name = newName;
    }

    function version() external pure returns (string memory) {
        return "v2";
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}
}