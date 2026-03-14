// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

contract BridgeRelayer {
    address public owner;
    mapping(address => bool) public isRelayer;

    event RelayerAdded(address indexed relayer);
    event RelayerRemoved(address indexed relayer);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    modifier onlyRelayer() {
        require(isRelayer[msg.sender], "Not a relayer");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function addRelayer(address _relayer) public onlyOwner {
        require(_relayer != address(0), "Invalid address");
        isRelayer[_relayer] = true;
        emit RelayerAdded(_relayer);
    }

    function removeRelayer(address _relayer) public onlyOwner {
        require(isRelayer[_relayer], "Not a relayer");
        isRelayer[_relayer] = false;
        emit RelayerRemoved(_relayer);
    }

    function relayMessage(bytes memory _message) public onlyRelayer {
        // Placeholder for message relay logic
    }
}