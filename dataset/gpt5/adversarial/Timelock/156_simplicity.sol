// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Timelock {
    address payable public immutable beneficiary;
    uint256 public immutable releaseTime;

    constructor(address payable _beneficiary, uint256 _releaseTime) {
        require(_releaseTime > block.timestamp, "Release time in past");
        beneficiary = _beneficiary;
        releaseTime = _releaseTime;
    }

    receive() external payable {}

    function withdraw() external {
        require(msg.sender == beneficiary, "Not beneficiary");
        require(block.timestamp >= releaseTime, "Too early");
        uint256 amount = address(this).balance;
        require(amount > 0, "No funds");
        (bool ok, ) = beneficiary.call{value: amount}("");
        require(ok, "Transfer failed");
    }
}