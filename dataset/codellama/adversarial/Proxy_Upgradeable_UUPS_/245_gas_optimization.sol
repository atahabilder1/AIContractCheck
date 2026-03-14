// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Proxy {
    address private _implementation;

    constructor() public {
        _implementation = address(this);
    }

    function upgradeTo(address newImplementation) external {
        _implementation = newImplementation;
    }

    function delegate(address target) internal {
        address impl = _implementation;
        assembly {
            let ptr := mload(0x40)
            calldatacopy(ptr, 0, calldatasize())
            let result := delegatecall(gas(), impl, ptr, calldatasize(), 0, 0)
            returndatacopy(ptr, 0, returndatasize())
            switch result
            case 0 { revert(ptr, returndatasize()) }
            default { return(ptr, returndatasize()) }
        }
    }

    fallback() external {
        delegate(_implementation);
    }
}