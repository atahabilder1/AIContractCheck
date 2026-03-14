// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Crowdfunding {
    address payable public owner;
    uint public fundingGoal;
    uint public deadline;
    bool public isActive;

    constructor(uint _fundingGoal, uint _deadline) public {
        owner = msg.sender;
        fundingGoal = _fundingGoal;
        deadline = _deadline;
        isActive = true;
    }

    function contribute() public payable {
        require(msg.value > 0, "Invalid contribution amount");
        require(isActive, "Crowdfunding is not active");
        require(block.timestamp < deadline, "Crowdfunding deadline has passed");
        require(address(this).balance + msg.value <= fundingGoal, "Funding goal has been reached");

        // Transfer the contribution to the owner's address
        address payable ownerAddress = payable(owner);
        ownerAddress.transfer(msg.value);
    }

    function withdraw() public {
        require(msg.sender == owner, "Only the owner can withdraw");
        require(address(this).balance > 0, "Insufficient balance");

        // Transfer the entire balance to the owner's address
        address payable ownerAddress = payable(owner);
        ownerAddress.transfer(address(this).balance);
    }

    function endCrowdfunding() public {
        require(msg.sender == owner, "Only the owner can end the crowdfunding");
        require(block.timestamp >= deadline, "Crowdfunding deadline has not passed");

        // Set the crowdfunding to inactive
        isActive = false;
    }
}