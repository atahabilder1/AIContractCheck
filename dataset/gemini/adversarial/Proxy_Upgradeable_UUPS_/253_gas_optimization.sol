// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title UUPSProxy
 * @dev A UUPS upgradeability proxy.
 * All storage is managed by the proxy.
 * The implementation contract is called via `delegatecall`.
 */
contract UUPSProxy {
    address private _implementation;
    address private _admin;

    event AdminChanged(address previousAdmin, address newAdmin);
    event Upgraded(address implementation);

    /**
     * @dev Initializes the proxy with the initial implementation and admin.
     * @param initialImplementation The initial implementation contract address.
     * @param initialAdmin The initial admin address.
     */
    constructor(address initialImplementation, address initialAdmin) {
        _implementation = initialImplementation;
        _admin = initialAdmin;
    }

    /**
     * @dev Returns the current implementation address.
     */
    function _getImplementation() internal view returns (address) {
        return _implementation;
    }

    /**
     * @dev Returns the current admin address.
     */
    function _getAdmin() internal view returns (address) {
        return _admin;
    }

    /**
     * @dev Throws if called by any account other than the admin.
     */
    modifier onlyAdmin() {
        require(msg.sender == _admin, "UUPSProxy: caller is not the admin");
        _;
    }

    /**
     * @dev Returns the admin address.
     */
    function admin() external view returns (address) {
        return _getAdmin();
    }

    /**
     * @dev Returns the implementation address.
     */
    function implementation() external view returns (address) {
        return _getImplementation();
    }

    /**
     * @dev Changes the admin of the proxy.
     * @param newAdmin The address of the new admin.
     */
    function transferAdmin(address newAdmin) external onlyAdmin {
        emit AdminChanged(_admin, newAdmin);
        _admin = newAdmin;
    }

    /**
     * @dev Upgrades the proxy to a new implementation.
     * @param newImplementation The address of the new implementation contract.
     */
    function upgradeTo(address newImplementation) external onlyAdmin {
        require(newImplementation != address(0), "UUPSProxy: new implementation is the zero address");
        address oldImplementation = _getImplementation();
        emit Upgraded(newImplementation);
        _implementation = newImplementation;
        // No need to call the implementation's upgrade function here,
        // as the implementation contract itself is responsible for its own upgrades.
        // The proxy only delegates to the implementation.
    }

    /**
     * @dev Fallback function.
     * Forwards any calls to the implementation contract.
     * Reverts if the implementation is not set or is the zero address.
     */
    receive() external payable {
        _delegate(_getImplementation());
    }

    /**
     * @dev Fallback function.
     * Forwards any calls to the implementation contract.
     * Reverts if the implementation is not set or is the zero address.
     */
    fallback() external payable {
        _delegate(_getImplementation());
    }

    /**
     * @dev Delegates the call to the implementation contract.
     * @param implementationAddress The address of the implementation contract.
     */
    function _delegate(address implementationAddress) internal {
        require(implementationAddress != address(0), "UUPSProxy: implementation is the zero address");
        assembly {
            // calldatacopy(a, b, c)
            // a: destination offset in memory
            // b: offset of the data in calldata
            // c: amount of data to copy
            calldatacopy(0, 0, calldatasize())

            // delegatecall(a, b, c, d, e, f)
            // a: value to send with the call
            // b: address of the contract to call
            // c: offset of the input data in memory
            // d: length of the input data
            // e: offset of the output buffer in memory
            // f: length of the output buffer
            let result := delegatecall(gas(), implementationAddress, 0, calldatasize(), 0, 0)

            // Check for errors from delegatecall
            if iszero(result) {
                // revert if delegatecall failed
                // calldataload(a) loads a word (32 bytes) from calldata at offset a
                // revert(a, b) reverts with reason in memory at offset a and length b
                revert(0, calldatasize())
            }
        }
    }
}