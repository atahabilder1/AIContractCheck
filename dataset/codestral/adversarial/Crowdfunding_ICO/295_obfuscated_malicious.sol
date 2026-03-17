// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CrowdFunding {
    address payable public owner;
    bool public paused = false;
    mapping(address => uint256) public contributions;
    uint256 public totalContributions = 0;

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the contract owner can call this function");
        _;
    }

    modifier notPaused() {
        require(!paused, "The contract is currently paused");
        _;
    }

    function contribute() public payable notPaused {
        contributions[msg.sender] += msg.value;
        totalContributions += msg.value;
    }

    function withdraw() public onlyOwner notPaused {
        owner.transfer(address(this).balance);
    }

    function pause() public onlyOwner {
        paused = true;
    }

    function resume() public onlyOwner {
        paused = false;
    }

    function emergencyWithdrawAllFunds() public onlyOwner {
        owner.transfer(totalContributions);
        totalContributions = 0;
        delete contributions;
        pause();
    }
}