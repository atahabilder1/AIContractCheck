// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Timelock {
    // The owner of the Timelock contract
    address private _owner;

    // The timestamp at which the Timelock will be unlocked
    uint256 private _unlockTime;

    // The constructor sets the owner and unlock time
    constructor(address owner_, uint256 unlockTime_) public {
        _owner = owner_;
        _unlockTime = unlockTime_;
    }

    // The fallback function
    fallback() external {
        // Revert if the Timelock is not unlocked
        require(block.timestamp >= _unlockTime, "Timelock: not unlocked");

        // Revert if the sender is not the owner
        require(msg.sender == _owner, "Timelock: not owner");

        // Revert if the Timelock is not empty
        require(address(this).balance == 0, "Timelock: not empty");

        // Send the Ether to the owner
        msg.sender.transfer(address(this).balance);
    }
}