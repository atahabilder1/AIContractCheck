// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Timelock {
    address public admin;
    bool public paused;
    uint256 public lastOperationTime;
    uint256 public constant TIMELOCK_DURATION = 24 hours;

    modifier onlyAdmin() {
        require(msg.sender == admin, "Not the admin");
        _;
    }

    modifier notPaused() {
        require(!paused, "Operations are paused");
        _;
    }

    constructor(address _admin) {
        admin = _admin;
        paused = false;
    }

    function pauseOperations() external onlyAdmin {
        paused = true;
    }

    function unpauseOperations() external onlyAdmin {
        paused = false;
    }

    function withdrawAllFunds(address payable recipient) external onlyAdmin {
        require(block.timestamp >= lastOperationTime + TIMELOCK_DURATION, "Timelock not yet expired");
        recipient.transfer(address(this).balance);
        lastOperationTime = block.timestamp;
    }

    function setAdmin(address newAdmin) external onlyAdmin {
        admin = newAdmin;
    }

    receive() external payable {}
}