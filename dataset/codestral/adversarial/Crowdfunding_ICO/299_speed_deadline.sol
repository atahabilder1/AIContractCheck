// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract ICO {
    address public owner;
    uint256 public goalAmount;
    uint256 public deadline;
    mapping(address => uint256) public contributions;
    bool public isCompleted;

    constructor(uint256 _goal, uint256 _deadline) {
        owner = msg.sender;
        goalAmount = _goal;
        deadline = _deadline;
    }

    function contribute() public payable {
        require(!isCompleted && block.timestamp < deadline);
        contributions[msg.sender] += msg.value;
    }

    function withdraw() public onlyOwner {
        require(block.timestamp >= deadline, "ICO not completed yet");
        isCompleted = true;
        owner.transfer(address(this).balance);
    }

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }
}