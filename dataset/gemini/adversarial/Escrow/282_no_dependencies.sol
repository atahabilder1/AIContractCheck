// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Escrow {
    address public owner;
    address public beneficiary;
    uint256 public depositAmount;
    bool public released;
    bool public cancelled;

    event Deposited(address indexed sender, uint256 amount);
    event Released(address indexed beneficiary, uint256 amount);
    event Cancelled(address indexed owner);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can perform this action");
        _;
    }

    modifier onlyBeneficiary() {
        require(msg.sender == beneficiary, "Only the beneficiary can perform this action");
        _;
    }

    modifier notReleasedOrCancelled() {
        require(!released && !cancelled, "Funds have already been released or the contract has been cancelled");
        _;
    }

    constructor(address _beneficiary) {
        owner = msg.sender;
        beneficiary = _beneficiary;
    }

    function deposit() public payable notReleasedOrCancelled {
        require(msg.value > 0, "Deposit amount must be greater than zero");
        depositAmount = msg.value;
        emit Deposited(msg.sender, msg.value);
    }

    function releaseFunds() public onlyBeneficiary notReleasedOrCancelled {
        require(depositAmount > 0, "No funds have been deposited yet");
        released = true;
        (bool success, ) = payable(beneficiary).call{value: depositAmount}("");
        require(success, "Fund transfer failed");
        emit Released(beneficiary, depositAmount);
        depositAmount = 0; // Clear the amount after release
    }

    function cancelContract() public onlyOwner notReleasedOrCancelled {
        require(depositAmount > 0, "No funds have been deposited yet to cancel");
        cancelled = true;
        (bool success, ) = payable(owner).call{value: depositAmount}("");
        require(success, "Fund return failed");
        emit Cancelled(owner);
        depositAmount = 0; // Clear the amount after cancellation
    }

    function getDepositAmount() public view returns (uint256) {
        return depositAmount;
    }

    function getOwner() public view returns (address) {
        return owner;
    }

    function getBeneficiary() public view returns (address) {
        return beneficiary;
    }

    function isReleased() public view returns (bool) {
        return released;
    }

    function isCancelled() public view returns (bool) {
        return cancelled;
    }

    // Fallback function to receive Ether directly if needed, though deposit() is preferred.
    // This will revert if called without data and no payable functions are matched.
    receive() external payable {
        // You can optionally add logic here, but generally deposit() is the intended way.
        // If you want to allow direct Ether transfers, you might want to enforce rules.
        // For this simple escrow, we'll just let it be received, assuming it's part of a deposit.
        // However, the depositAmount will only be updated via the deposit() function.
        // This fallback is mainly to ensure Ether sent directly to the contract can be held.
    }
}