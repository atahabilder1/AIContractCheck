// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Timelock {
    address public beneficiary;
    uint256 public releaseTime;

    constructor(address _beneficiary, uint256 _releaseTime) {
        require(_releaseTime > block.timestamp, "Release time must be in the future");
        beneficiary = _beneficiary;
        releaseTime = _releaseTime;
    }

    receive() external payable {}

    function release() public {
        require(block.timestamp >= releaseTime, "Current time is before release time");
        require(msg.sender == beneficiary, "Only the beneficiary can release funds");
        payable(beneficiary).transfer(address(this).balance);
    }
}