// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CrossChainMessaging {
    address public admin;
    bool public isPaused;

    event MessageSent(address indexed from, address indexed to, string message);
    event FundsWithdrawn(address indexed admin, uint amount);
    event OperationPaused(address indexed admin, bool isPaused);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Not authorized");
        _;
    }

    modifier whenNotPaused() {
        require(!isPaused, "Operation is paused");
        _;
    }

    constructor() {
        admin = msg.sender;
        isPaused = false;
    }

    function sendMessage(address to, string memory message) external whenNotPaused {
        emit MessageSent(msg.sender, to, message);
    }

    function withdrawFunds(uint amount) external onlyAdmin {
        payable(admin).transfer(amount);
        emit FundsWithdrawn(admin, amount);
    }

    function pauseOperations(bool _isPaused) external onlyAdmin {
        isPaused = _isPaused;
        emit OperationPaused(admin, isPaused);
    }

    receive() external payable {}
}