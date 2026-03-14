// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract ProportionalTimelock {
    address public owner;
    uint256 public constant BASE_DELAY = 1 days;
    uint256 public constant DELAY_MULTIPLIER = 1 days; // Every 1 ETH adds 1 day

    struct Timelock {
        uint256 amount;
        uint256 releaseTime;
    }

    mapping(address => Timelock) public timelocks;

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the contract owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function deposit() external payable {
        require(msg.value > 0, "Must deposit positive amount");

        uint256 delay = BASE_DELAY + (msg.value * DELAY_MULTIPLIER) / 1 ether;
        uint256 releaseTime = block.timestamp + delay;

        Timelock storage timelock = timelocks[msg.sender];
        timelock.amount += msg.value;
        timelock.releaseTime = releaseTime;
    }

    function withdraw() external {
        Timelock storage timelock = timelocks[msg.sender];
        require(timelock.amount > 0, "No funds to withdraw");
        require(block.timestamp >= timelock.releaseTime, "Funds are still locked");

        uint256 amount = timelock.amount;
        timelock.amount = 0;

        payable(msg.sender).transfer(amount);
    }

    function getTimelockInfo(address _account) external view returns (uint256 amount, uint256 releaseTime) {
        Timelock storage timelock = timelocks[_account];
        return (timelock.amount, timelock.releaseTime);
    }

    function emergencyWithdraw() external onlyOwner {
        payable(owner).transfer(address(this).balance);
    }
}