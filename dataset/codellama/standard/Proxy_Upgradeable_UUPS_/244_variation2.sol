// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Proxy {
    address public owner;
    address public implementation;

    constructor() public {
        owner = msg.sender;
    }

    function upgrade(address newImplementation) public {
        require(msg.sender == owner, "Only owner can upgrade");
        implementation = newImplementation;
    }
}

contract Admin {
    address public owner;
    address public proxy;

    constructor(address _proxy) public {
        owner = msg.sender;
        proxy = _proxy;
    }

    function upgradeProxy(address newImplementation) public {
        require(msg.sender == owner, "Only owner can upgrade");
        Proxy(proxy).upgrade(newImplementation);
    }
}