// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Crowdfunding {
  // Crowdfunding parameters
  address public owner;
  uint256 public goal;
  uint256 public endTime;
  uint256 public totalContributions;

  // Constructor function
  constructor(uint256 _goal, uint256 _endTime) public {
    owner = msg.sender;
    goal = _goal;
    endTime = _endTime;
  }

  // Function to contribute to the crowdfunding campaign
  function contribute() public payable {
    require(msg.value > 0, "Invalid contribution amount");
    require(block.timestamp < endTime, "Crowdfunding campaign has ended");
    totalContributions += msg.value;
  }

  // Function to retrieve the total contributions
  function getTotalContributions() public view returns (uint256) {
    return totalContributions;
  }
}