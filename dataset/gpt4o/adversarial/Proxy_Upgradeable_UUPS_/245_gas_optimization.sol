// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

abstract contract Proxy {
    fallback() external payable virtual {
        _delegate(_implementation());
    }

    receive() external payable virtual {
        _delegate(_implementation());
    }

    function _delegate(address implementation) internal virtual {
        assembly {
            // Copy msg.data. We take full control of memory in this inline assembly
            // block because it will not return to Solidity code. We overwrite the
            // Solidity scratch pad at memory position 0.
            calldatacopy(0, 0, calldatasize())

            // Call the implementation.
            // out and outsize are 0 because we don't know the size yet.
            let result := delegatecall(gas(), implementation, 0, calldatasize(), 0, 0)

            // Copy the returned data.
            returndatacopy(0, 0, returndatasize())

            switch result
            // delegatecall returns 0 on error.
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }

    function _implementation() internal view virtual returns (address);
}

contract UUPSProxy is Proxy {
    address private immutable _admin;
    address private _implementationAddress;

    modifier ifAdmin() {
        require(msg.sender == _admin, "UUPSProxy: caller is not admin");
        _;
    }

    constructor(address initialImplementation) {
        _admin = msg.sender;
        _implementationAddress = initialImplementation;
    }

    function _implementation() internal view override returns (address) {
        return _implementationAddress;
    }

    function upgradeTo(address newImplementation) external ifAdmin {
        _implementationAddress = newImplementation;
    }
}

contract ImplementationV1 {
    uint256 public value;

    function setValue(uint256 newValue) external {
        value = newValue;
    }
}

contract ImplementationV2 {
    uint256 public value;

    function setValue(uint256 newValue) external {
        value = newValue * 2; // Different logic for demonstration
    }
}