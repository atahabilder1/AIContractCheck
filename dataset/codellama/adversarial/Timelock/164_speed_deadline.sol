// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Timelock {
    address private _owner;
    uint256 private _releaseTime;

    constructor(uint256 releaseTime_) public {
        _owner = msg.sender;
        _releaseTime = releaseTime_;
    }

    function release() public {
        require(block.timestamp >= _releaseTime, "Timelock: release time not reached");
        selfdestruct(payable(_owner));
    }

    function getReleaseTime() public view returns (uint256) {
        return _releaseTime;
    }
}