SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract Timelock {
    address private _owner;
    uint256 private _releaseTime;

    constructor(address owner_, uint256 releaseTime_) {
        _owner = owner_;
        _releaseTime = releaseTime_;
    }

    function release() public {
        require(msg.sender == _owner, "Only the owner can release the timelock");
        require(block.timestamp >= _releaseTime, "The release time has not been reached");

        // Transfer the funds to the owner
        payable(_owner).transfer(address(this).balance);
    }
}