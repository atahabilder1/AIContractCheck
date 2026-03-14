// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract BridgeRelayer {
    event Relayed(address indexed from, bytes32 indexed payload);

    mapping(address => bool) public isRelayer;

    constructor() public {
        isRelayer[msg.sender] = true;
    }

    function setRelayer(address relayer) public {
        isRelayer[relayer] = true;
    }

    function unsetRelayer(address relayer) public {
        isRelayer[relayer] = false;
    }

    function relay(address from, bytes32 payload) public {
        require(isRelayer[msg.sender], "Not a relayer");
        emit Relayed(from, payload);
    }
}