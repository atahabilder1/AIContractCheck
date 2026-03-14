// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Crowdfunding {
    address public owner;
    uint public goal;
    uint public deadline;
    uint public raised;
    mapping(address => uint) public contributions;

    constructor(uint _goal, uint _deadline) public {
        owner = msg.sender;
        goal = _goal;
        deadline = _deadline;
    }

    function contribute() public payable {
        require(msg.value > 0, "Invalid contribution amount");
        require(block.timestamp < deadline, "Crowdfunding is already over");
        contributions[msg.sender] += msg.value;
        raised += msg.value;
    }

    function withdraw() public {
        require(msg.sender == owner, "Only the owner can withdraw");
        require(raised >= goal, "Crowdfunding goal not met");
        payable(msg.sender).transfer(raised);
    }

    function getContributions() public view returns (mapping(address => uint)) {
        return contributions;
    }
}