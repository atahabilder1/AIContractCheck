// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

abstract contract Proxy {
    function _delegate(address implementation) internal virtual {
        assembly {
            // Copy msg.data. We take full control of memory in this inline assembly
            // block because it will be used to construct the calldata for the delegatecall.
            calldatacopy(0, 0, calldatasize())

            // Delegatecall to the implementation contract.
            let result := delegatecall(gas(), implementation, 0, calldatasize(), 0, 0)

            // Copy the returned data from the delegatecall to memory.
            returndatacopy(0, 0, returndatasize())

            switch result
            // Delegatecall returned successfully.
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }

    function _implementation() internal view virtual returns (address);

    function _fallback() internal virtual {
        _delegate(_implementation());
    }

    fallback() external payable {
        _fallback();
    }

    receive() external payable {
        _fallback();
    }
}

contract UpgradeableProxy is Proxy {
    address private immutable _implementation;

    constructor(address implementation) {
        _implementation = implementation;
    }

    function _implementation() internal view override returns (address) {
        return _implementation;
    }

    function upgradeTo(address newImplementation) public {
        require(msg.sender == address(this), "Only self can upgrade");
        _implementation = newImplementation;
    }
}