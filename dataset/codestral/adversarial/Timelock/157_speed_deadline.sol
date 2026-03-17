// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Timelock {
    using SafeMath for uint256;

    address payable public owner;
    uint256 public timeLockDuration;
    uint256 public releaseTime;

    constructor(uint256 _timeLockDuration) {
        owner = payable(msg.sender);
        timeLockDuration = _timeLockDuration;
        releaseTime = block.timestamp + timeLockDuration;
    }

    function releaseFunds() public {
        require(block.timestamp >= releaseTime, "Timelock not expired");
        owner.transfer(address(this).balance);
    }

    receive() external payable {}
}