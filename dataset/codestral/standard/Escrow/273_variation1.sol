// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Escrow {
    address public payee;
    address public beneficiary;
    uint256 public totalPrice;
    mapping(uint => bool) public milestonesCompleted;
    uint256 public numberOfMilestones;
    uint256 private currentMilestoneIndex = 0;

    event PaymentReleased(address indexed to, uint256 amount);

    constructor(address _payee, address _beneficiary, uint256 _totalPrice, uint256 _numberOfMilestones) {
        payee = _payee;
        beneficiary = _beneficiary;
        totalPrice = _totalPrice;
        numberOfMilestones = _numberOfMilestones;
    }

    function approveDeliverable() public {
        require(msg.sender == payee, "Only the payee can call this.");
        require(!milestonesCompleted[currentMilestoneIndex], "This milestone has already been completed.");

        milestonesCompleted[currentMilestoneIndex] = true;
        currentMilestoneIndex++;

        if (currentMilestoneIndex == numberOfMilestones) {
            releasePayment(totalPrice);
        } else {
            uint256 amountToRelease = totalPrice / numberOfMilestones;
            releasePayment(amountToRelease);
        }
    }

    function releasePayment(uint256 amount) private {
        beneficiary.transfer(amount);
        emit PaymentReleased(beneficiary, amount);
    }
}