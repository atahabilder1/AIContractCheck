// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Timelock {
    address public timelock;
    uint256 public releaseTime;
    uint256 public remainingAmount;

    constructor(address _timelock, uint256 _releaseTime) {
        timelock = _timelock;
        releaseTime = _releaseTime;
    }

    function deposit() external payable {
        if (msg.sender == timelock && block.timestamp < releaseTime) {
            remainingAmount += msg.value;
        }
    }

    function withdraw() public {
        require(block.timestamp >= releaseTime, "Timelock has not expired");
        uint256 amount = remainingAmount;
        remainingAmount = 0;
        payable(msg.sender).transfer(amount);
    }
}