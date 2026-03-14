// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Proxy {
    address private _implementation;

    constructor(address implementation) public {
        _implementation = implementation;
    }

    function upgradeTo(address newImplementation) public {
        require(msg.sender == _implementation, "Only the current implementation can upgrade");
        _implementation = newImplementation;
    }

    fallback() external {
        address implementation = _implementation;
        assembly {
            // call the implementation's fallback function
            let ptr := mload(0x40)
            mstore(ptr, 0x00)
            return(ptr, 0x20)
        }
    }
}