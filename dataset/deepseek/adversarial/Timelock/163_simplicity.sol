// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Timelock {
    mapping(address => uint256) public balances;

    function deposit() public payable {
        balances[msg.sender] += msg.value;
    }

    function withdraw(uint256 amount) public {
        require(block.timestamp >= releaseTimes[msg.sender], "Tokens are not yet released");
        balances[msg.sender] -= amount;
        payable(msg.sender).transfer(amount);
    }

    mapping(address => uint256) public releaseTimes;

    function setReleaseTime(uint256 releaseTime) public {
        releaseTimes[msg.sender] = releaseTime;
    }
}