// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title UUPSUpgradeable
 * @dev A UUPS upgradeability contract that uses a separate implementation contract.
 * The upgradeTo function is called by an authorized address to set the implementation address.
 * The upgradeTo function can only be called if the contract is not initialized.
 * The initialize function can only be called once.
 */
contract UUPSUpgradeable {
    address private _implementation;
    address private _admin;
    bool private _initialized;

    event Upgraded(address indexed implementation);
    event Initialized(address indexed caller);

    /**
     * @dev Reverts if the contract has not been initialized.
     */
    modifier notInitialized() {
        require(!_initialized, "UUPSUpgradeable: contract already initialized");
        _;
    }

    /**
     * @dev Reverts if the contract has already been initialized.
     */
    modifier initialized() {
        require(_initialized, "UUPSUpgradeable: contract not initialized");
        _;
    }

    /**
     * @dev Returns the current implementation address.
     */
    function _getImplementation() internal view returns (address) {
        return _implementation;
    }

    /**
     * @dev Sets the implementation address.
     * @param newImplementation The new implementation address.
     */
    function _setImplementation(address newImplementation) internal {
        _implementation = newImplementation;
    }

    /**
     * @dev Returns the admin address.
     */
    function admin() public view returns (address) {
        return _admin;
    }

    /**
     * @dev Sets the admin address.
     * @param newAdmin The new admin address.
     */
    function _setAdmin(address newAdmin) internal {
        _admin = newAdmin;
    }

    /**
     * @dev Returns whether the contract has been initialized.
     */
    function initialized() public view returns (bool) {
        return _initialized;
    }

    /**
     * @dev Marks the contract as initialized.
     */
    function _markAsInitialized() internal {
        _initialized = true;
    }

    /**
     * @dev Called by the admin to upgrade the implementation.
     * @param newImplementation The new implementation address.
     */
    function upgradeTo(address newImplementation) public {
        require(msg.sender == _admin, "UUPSUpgradeable: caller is not the admin");
        require(newImplementation != address(0), "UUPSUpgradeable: new implementation is zero address");
        require(!_initialized, "UUPSUpgradeable: cannot upgrade after initialization");

        address oldImplementation = _implementation;
        _setImplementation(newImplementation);

        emit Upgraded(newImplementation);
    }

    /**
     * @dev Fallback function that delegates calls to the implementation contract.
     */
    fallback() external payable {
        address impl = _getImplementation();
        require(impl != address(0), "UUPSUpgradeable: no implementation address set");
        assembly {
            calldatecopy(0, calldata, calldatasize())
            let result := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
                case 0 { revert(0, returndatasize()) }
                default { return(0, returndatasize()) }
        }
    }

    /**
     * @dev Receive function that delegates calls to the implementation contract.
     */
    receive() external payable {
        fallback();
    }
}