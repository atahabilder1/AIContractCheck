// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Timelock {
    address public immutable owner;
    uint256 public immutable unlockTime;

    constructor(uint256 _unlockTime) {
        owner = msg.sender;
        unlockTime = _unlockTime;
    }

    receive() external payable {}

    function withdraw() external {
        require(msg.sender == owner, "Not the owner");
        require(block.timestamp >= unlockTime, "Funds are locked");
        payable(owner).transfer(address(this).balance);
    }
}