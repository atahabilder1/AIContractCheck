// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract DecentralizedRelayerNetwork {
    address private _owner;
    mapping(address => uint) private _relayerStakes;
    mapping(address => uint) private _relayerSlashing;
    address[] private _relayers;
    uint private _currentRelayerIndex;
    uint private _gasReimbursement;

    constructor() public {
        _owner = msg.sender;
    }

    function stake(uint amount) public {
        require(msg.sender != address(0), "Invalid address");
        require(amount > 0, "Invalid amount");
        _relayerStakes[msg.sender] = amount;
    }

    function unstake(uint amount) public {
        require(msg.sender != address(0), "Invalid address");
        require(amount > 0, "Invalid amount");
        require(_relayerStakes[msg.sender] >= amount, "Insufficient stake");
        _relayerStakes[msg.sender] -= amount;
    }

    function slash(address relayer, uint amount) public {
        require(msg.sender == _owner, "Only owner can slash");
        require(amount > 0, "Invalid amount");
        require(_relayerStakes[relayer] >= amount, "Insufficient stake");
        _relayerSlashing[relayer] += amount;
    }

    function assignRelayer() public {
        require(_relayers.length > 0, "No relayers available");
        _currentRelayerIndex = (_currentRelayerIndex + 1) % _relayers.length;
        return _relayers[_currentRelayerIndex];
    }

    function reimburseGas() public {
        require(msg.sender != address(0), "Invalid address");
        uint gasUsed = tx.gasprice * tx.gaslimit;
        _gasReimbursement += gasUsed;
    }

    function getRelayer(uint index) public view returns (address) {
        require(index < _relayers.length, "Invalid index");
        return _relayers[index];
    }

    function getStake(address relayer) public view returns (uint) {
        require(relayer != address(0), "Invalid address");
        return _relayerStakes[relayer];
    }

    function getSlashing(address relayer) public view returns (uint) {
        require(relayer != address(0), "Invalid address");
        return _relayerSlashing[relayer];
    }

    function getGasReimbursement() public view returns (uint) {
        return _gasReimbursement;
    }
}