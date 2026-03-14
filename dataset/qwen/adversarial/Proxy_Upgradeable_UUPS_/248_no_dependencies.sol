// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract UUPSProxy {
    address private _implementation;
    address private _admin;

    event Upgraded(address indexed implementation);
    event AdminChanged(address indexed previousAdmin, address indexed newAdmin);

    modifier onlyAdmin() {
        require(msg.sender == _admin, "UUPSProxy: caller is not the admin");
        _;
    }

    constructor(address initialAdmin, address initialImplementation) {
        _admin = initialAdmin;
        _implementation = initialImplementation;
        emit AdminChanged(address(0), initialAdmin);
        emit Upgraded(initialImplementation);
    }

    function _setImplementation(address newImplementation) internal {
        require(newImplementation != address(0), "UUPSProxy: new implementation is the zero address");
        _implementation = newImplementation;
        emit Upgraded(newImplementation);
    }

    function upgradeTo(address newImplementation) external onlyAdmin {
        require(newImplementation != _implementation, "UUPSProxy: already upgraded to the new implementation");
        require(
            _checkUpgradability(newImplementation),
            "UUPSProxy: new implementation is not upgradable"
        );
        _setImplementation(newImplementation);
    }

    function _checkUpgradability(address newImplementation) private view returns (bool) {
        (bool success, bytes memory data) = newImplementation.staticcall(
            abi.encodeWithSelector(UUPSUpgradeable._authorizeUpgrade.selector, address(this))
        );
        return success && data.length > 0 && abi.decode(data, (bool));
    }

    function _getImplementation() internal view returns (address) {
        return _implementation;
    }

    function _getAdmin() internal view returns (address) {
        return _admin;
    }

    function _setAdmin(address newAdmin) internal {
        require(newAdmin != address(0), "UUPSProxy: new admin is the zero address");
        address oldAdmin = _admin;
        _admin = newAdmin;
        emit AdminChanged(oldAdmin, newAdmin);
    }

    function changeAdmin(address newAdmin) external onlyAdmin {
        _setAdmin(newAdmin);
    }

    fallback() external payable {
        address target = _implementation;
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), target, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    receive() external payable {}
}

abstract contract UUPSUpgradeable {
    function _authorizeUpgrade(address) internal virtual;
}