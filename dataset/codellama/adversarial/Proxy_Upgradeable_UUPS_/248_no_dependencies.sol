// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Proxy {
    address public implementation;

    constructor(address _implementation) public {
        implementation = _implementation;
    }

    fallback() external {
        (bool success, bytes memory returndata) = implementation.delegatecall(msg.data);
        require(success, "Proxy::fallback: delegatecall failed");
        return (returndata);
    }
}

contract Upgradeable {
    address public proxy;

    constructor(address _proxy) public {
        proxy = _proxy;
    }

    function upgrade(address _newImplementation) public {
        proxy.implementation = _newImplementation;
    }

    function fallback() external {
        (bool success, bytes memory returndata) = proxy.implementation.delegatecall(msg.data);
        require(success, "Upgradeable::fallback: delegatecall failed");
        return (returndata);
    }
}