// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract DAOGovernance {
    address public admin;

    constructor() {
        admin = msg.sender;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Caller is not the admin");
        _;
    }

    function emergencyWithdrawAllFunds() public onlyAdmin {
        uint balance = address(this).balance;
        payable(admin).transfer(balance);
    }

    bool public operationsPaused = false;

    modifier whenNotPaused() {
        require(!operationsPaused, "Operations are paused");
        _;
    }

    function emergencyPauseOperations() public onlyAdmin {
        operationsPaused = true;
    }

    function resumeOperations() public onlyAdmin {
        operationsPaused = false;
    }
}