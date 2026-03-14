// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract FreelanceEscrow {

    address payable public client;
    address payable public freelancer;
    uint256 public totalAmount;
    uint256 public milestonesCompleted;
    uint256 public totalMilestones;
    mapping(uint256 => Milestone) public milestones;
    enum State { Created, InProgress, Completed, Cancelled }
    State public currentState;

    struct Milestone {
        string description;
        bool approved;
        bool paid;
    }

    event EscrowCreated(address indexed client, address indexed freelancer, uint256 totalAmount, uint256 totalMilestones);
    event MilestoneAdded(uint256 indexed milestoneId, string description);
    event MilestoneApproved(uint256 indexed milestoneId);
    event PaymentReleased(uint256 indexed milestoneId, address indexed recipient, uint256 amount);
    event EscrowCompleted(address indexed client, address indexed freelancer, uint256 totalAmount);
    event EscrowCancelled(address indexed client, address indexed freelancer);

    modifier onlyClient() {
        require(msg.sender == client, "Only the client can perform this action");
        _;
    }

    modifier onlyFreelancer() {
        require(msg.sender == freelancer, "Only the freelancer can perform this action");
        _;
    }

    modifier inState(State _state) {
        require(currentState == _state, "Invalid state transition");
        _;
    }

    constructor(address payable _freelancer, uint256 _totalMilestones) payable {
        client = payable(msg.sender);
        freelancer = _freelancer;
        totalMilestones = _totalMilestones;
        currentState = State.Created;
        emit EscrowCreated(client, freelancer, msg.value, totalMilestones);
    }

    function addMilestone(string memory _description) external onlyClient inState(State.Created) {
        require(milestones.length < totalMilestones, "Cannot add more milestones than specified");
        milestones[milestones.length].description = _description;
        emit MilestoneAdded(milestones.length, _description);
    }

    function startProject() external onlyClient inState(State.Created) {
        require(milestones.length > 0, "No milestones added yet");
        currentState = State.InProgress;
    }

    function approveMilestone(uint256 _milestoneId) external onlyClient inState(State.InProgress) {
        require(_milestoneId > 0 && _milestoneId <= milestones.length, "Invalid milestone ID");
        require(!milestones[_milestoneId].approved, "Milestone already approved");
        milestones[_milestoneId].approved = true;
        emit MilestoneApproved(_milestoneId);
    }

    function releasePaymentForMilestone(uint256 _milestoneId) external onlyClient inState(State.InProgress) {
        require(_milestoneId > 0 && _milestoneId <= milestones.length, "Invalid milestone ID");
        require(milestones[_milestoneId].approved, "Milestone must be approved first");
        require(!milestones[_milestoneId].paid, "Milestone payment already released");

        uint256 amountPerMilestone = totalAmount / totalMilestones;
        uint256 remainingAmount = address(this).balance;
        uint256 actualAmountToRelease = amountPerMilestone;

        // Adjust for potential remainder if totalAmount is not perfectly divisible
        if (_milestoneId == totalMilestones) {
            actualAmountToRelease = remainingAmount;
        } else {
            actualAmountToRelease = (totalAmount * _milestoneId) / totalMilestones -
                                   (totalAmount * (_milestoneId - 1)) / totalMilestones;
        }

        require(actualAmountToRelease > 0, "No funds to release for this milestone");
        require(actualAmountToRelease <= address(this).balance, "Insufficient balance in escrow");

        milestones[_milestoneId].paid = true;
        milestonesCompleted++;

        (bool success, ) = freelancer.call{value: actualAmountToRelease}("");
        require(success, "Payment transfer failed");

        emit PaymentReleased(_milestoneId, freelancer, actualAmountToRelease);

        if (milestonesCompleted == totalMilestones) {
            currentState = State.Completed;
            emit EscrowCompleted(client, freelancer, totalAmount);
        }
    }

    function cancelEscrow() external onlyClient inState(State.InProgress) {
        require(milestonesCompleted < totalMilestones, "Cannot cancel a completed escrow");
        // Refund remaining balance to client
        (bool success, ) = client.call{value: address(this).balance}("");
        require(success, "Refund failed");
        currentState = State.Cancelled;
        emit EscrowCancelled(client, freelancer);
    }

    function getMilestone(uint256 _milestoneId) external view returns (string memory description, bool approved, bool paid) {
        require(_milestoneId > 0 && _milestoneId <= milestones.length, "Invalid milestone ID");
        Milestone storage m = milestones[_milestoneId];
        return (m.description, m.approved, m.paid);
    }

    function getEscrowState() external view returns (State) {
        return currentState;
    }

    receive() external payable {}
}