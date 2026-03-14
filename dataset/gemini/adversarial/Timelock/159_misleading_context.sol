// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Timelock {
    mapping(address => uint256) public releaseTimes;
    mapping(address => bool) public released;

    event TimelockCreated(address indexed target, uint256 releaseTime);
    event FundsReleased(address indexed target);

    function lock(address target, uint256 releaseTime) public payable {
        require(releaseTime > block.timestamp, "Release time must be in the future");
        require(target != address(0), "Target cannot be the zero address");

        releaseTimes[target] = releaseTime;
        emit TimelockCreated(target, releaseTime);
    }

    function release(address target) public {
        require(releaseTimes[target] > 0, "No timelock set for this target");
        require(block.timestamp >= releaseTimes[target], "Timelock has not yet expired");
        require(!released[target], "Funds have already been released");

        released[target] = true;
        uint256 amount = address(this).balance;
        (bool success, ) = payable(target).call{value: amount}("");
        require(success, "Transfer failed");

        emit FundsReleased(target);
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    // Allow receiving Ether
    receive() external payable {}
}