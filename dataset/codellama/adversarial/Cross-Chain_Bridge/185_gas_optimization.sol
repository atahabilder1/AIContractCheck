// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CrossChainBridge {
    address public owner;
    mapping(address => mapping(uint256 => bool)) public registeredChains;
    mapping(address => mapping(uint256 => bool)) public registeredBridges;

    constructor() public {
        owner = msg.sender;
    }

    function registerChain(address _chain, uint256 _chainId) public {
        require(msg.sender == owner, "Only the owner can register chains");
        require(!registeredChains[_chain][_chainId], "Chain already registered");
        registeredChains[_chain][_chainId] = true;
    }

    function registerBridge(address _bridge, uint256 _chainId) public {
        require(msg.sender == owner, "Only the owner can register bridges");
        require(registeredChains[_bridge][_chainId], "Bridge chain not registered");
        registeredBridges[_bridge][_chainId] = true;
    }

    function crossChain(address _from, address _to, uint256 _amount) public {
        require(registeredChains[_from][msg.sender], "From chain not registered");
        require(registeredChains[_to][msg.sender], "To chain not registered");
        require(registeredBridges[_from][msg.sender], "From bridge not registered");
        require(registeredBridges[_to][msg.sender], "To bridge not registered");

        // Transfer the tokens
        // ...
    }
}