// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract FreelanceEscrow {
    address public client;
    address public freelancer;
    uint256 public totalAmount;
    uint256 public milestoneCount;
    uint256 public currentMilestone;

    enum State { AWAITING_DELIVERY, AWAITING_APPROVAL, COMPLETED }
    State public state;

    event MilestoneReleased(uint256 amount);
    event DeliverySubmitted(uint256 milestone);
    event ApprovalReceived(uint256 milestone);

    modifier onlyClient() {
        require(msg.sender == client, "Only client can call this function.");
        _;
    }

    modifier onlyFreelancer() {
        require(msg.sender == freelancer, "Only freelancer can call this function.");
        _;
    }

    modifier inState(State _state) {
        require(state == _state, "Invalid state for this operation.");
        _;
    }

    constructor(address _client, address _freelancer, uint256 _totalAmount, uint256 _milestoneCount) {
        client = _client;
        freelancer = _freelancer;
        totalAmount = _totalAmount;
        milestoneCount = _milestoneCount;
        state = State.AWAITING_DELIVERY;
    }

    function submitDelivery() external onlyFreelancer inState(State.AWAITING_DELIVERY) {
        require(currentMilestone < milestoneCount, "All milestones have been completed.");
        state = State.AWAITING_APPROVAL;
        emit DeliverySubmitted(currentMilestone);
    }

    function approveDelivery() external onlyClient inState(State.AWAITING_APPROVAL) {
        uint256 releaseAmount = totalAmount / milestoneCount;
        require(address(this).balance >= releaseAmount, "Insufficient funds in escrow.");

        payable(freelancer).transfer(releaseAmount);
        emit MilestoneReleased(releaseAmount);

        currentMilestone++;
        if (currentMilestone < milestoneCount) {
            state = State.AWAITING_DELIVERY;
        } else {
            state = State.COMPLETED;
        }
        emit ApprovalReceived(currentMilestone - 1);
    }

    function deposit() external payable onlyClient inState(State.AWAITING_DELIVERY) {
        require(msg.value > 0, "Deposit amount must be greater than zero.");
    }

    function cancel() external onlyClient inState(State.AWAITING_DELIVERY) {
        require(currentMilestone == 0, "Cannot cancel after delivery submission.");
        payable(client).transfer(address(this).balance);
    }
}