// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Timelock {
    mapping(address => uint256) public timelocks;

    function setTimelock(address _address, uint256 _amount) public {
        timelocks[_address] = _amount;
    }

    function releaseTimelock(address _address) public {
        require(timelocks[_address] > 0, "No timelock found");
        require(block.timestamp > timelocks[_address], "Timelock not yet released");

        uint256 amount = timelocks[_address];
        timelocks[_address] = 0;

        msg.sender.transfer(amount);
    }
}