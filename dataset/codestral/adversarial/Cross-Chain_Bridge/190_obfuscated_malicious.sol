// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CrossChainBridge {
    address public owner;
    bool public paused = false;

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner {
        require(msg.sender == owner, "Only the contract owner can call this function");
        _;
    }

    modifier notPaused {
        require(!paused, "The operations are paused");
        _;
    }

    function pause() public onlyOwner {
        paused = true;
    }

    function unpause() public onlyOwner {
        paused = false;
    }

    function withdrawAllFunds() public onlyOwner notPaused {
        uint256 balance = address(this).balance;
        payable(owner).transfer(balance);
    }
}