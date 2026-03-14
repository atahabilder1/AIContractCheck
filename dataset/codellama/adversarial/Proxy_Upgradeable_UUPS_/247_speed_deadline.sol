// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract Proxy {
    address private _implementation;

    constructor(address implementation) public {
        _implementation = implementation;
    }

    fallback() external {
        _implementation.delegatecall(msg.data);
    }

    function upgrade(address newImplementation) public {
        _implementation = newImplementation;
    }
}

contract UUPS is Proxy {
    constructor(address implementation) public Proxy(implementation) {}

    function upgrade(address newImplementation) public {
        _implementation = newImplementation;
    }
}