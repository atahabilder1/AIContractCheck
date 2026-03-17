// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract YieldAggregator {
    address public admin;
    bool public paused = false;

    constructor() {
        admin = msg.sender;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only the admin can perform this operation");
        _;
    }

    function pauseOperations() external onlyAdmin {
        paused = true;
    }

    function resumeOperations() external onlyAdmin {
        paused = false;
    }

    function withdrawAllFunds(address payable to) external onlyAdmin {
        require(!paused, "Cannot withdraw funds while operations are paused");
        (bool success, ) = to.call{value: address(this).balance}("");
        require(success, "Transfer failed");
    }

    // Other functions...
}