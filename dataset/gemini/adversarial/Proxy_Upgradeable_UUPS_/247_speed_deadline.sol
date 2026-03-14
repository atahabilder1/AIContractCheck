// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/Proxy.sol";

contract UUPSProxy is Proxy {
    address public immutable implementation;

    constructor(address _implementation) {
        implementation = _implementation;
    }

    function _delegate(address implementationAddress) internal override {
        assembly {
            // calldatacopy(offset, length) copies the calldata to memory
            calldatacopy(0, calldatasize(), calldatasize())
            // delegatecall returns a boolean success flag (0 for fail, 1 for success)
            // and the amount of returndata bytes.
            // The returndata is stored in memory starting at offset 0.
            let success := delegatecall(gas(), implementationAddress, 0, calldatasize(), 0, 0)
            // If delegatecall failed, revert.
            if iszero(success) {
                // Revert with the error message from the implementation.
                // returndatasize() returns the size of the returndata in bytes.
                // returndatacopy(dest, offset, length) copies returndata to memory.
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
        }
    }

    function _implementation() internal view override returns (address) {
        return implementation;
    }
}