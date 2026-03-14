// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract FreelanceEscrow {
    enum MilestoneStatus { Pending, Funded, Submitted, Approved, Disputed }
    enum ContractStatus { Active, Completed, Cancelled }

    struct Milestone {
        string description;
        uint256 amount;
        MilestoneStatus status;
    }

    address public client;
    address public freelancer;
    address public arbiter;
    ContractStatus public contractStatus;

    Milestone[] public milestones;
    uint256 public totalFunded;

    event MilestoneCreated(uint256 indexed milestoneId, string description, uint256 amount);
    event MilestoneFunded(uint256 indexed milestoneId, uint256 amount);
    event MilestoneSubmitted(uint256 indexed milestoneId);
    event MilestoneApproved(uint256 indexed milestoneId, uint256 amount);
    event DisputeRaised(uint256 indexed milestoneId);
    event DisputeResolved(uint256 indexed milestoneId, address recipient, uint256 amount);
    event ContractCancelled(uint256 refundedToClient);

    modifier onlyClient() {
        require(msg.sender == client, "Only client");
        _;
    }

    modifier onlyFreelancer() {
        require(msg.sender == freelancer, "Only freelancer");
        _;
    }

    modifier onlyArbiter() {
        require(msg.sender == arbiter, "Only arbiter");
        _;
    }

    modifier contractActive() {
        require(contractStatus == ContractStatus.Active, "Contract not active");
        _;
    }

    constructor(address _freelancer, address _arbiter) {
        require(_freelancer != address(0) && _arbiter != address(0), "Invalid address");
        require(_freelancer != msg.sender, "Client cannot be freelancer");
        client = msg.sender;
        freelancer = _freelancer;
        arbiter = _arbiter;
        contractStatus = ContractStatus.Active;
    }

    function addMilestone(string calldata _description, uint256 _amount) external onlyClient contractActive {
        require(_amount > 0, "Amount must be > 0");
        milestones.push(Milestone({
            description: _description,
            amount: _amount,
            status: MilestoneStatus.Pending
        }));
        emit MilestoneCreated(milestones.length - 1, _description, _amount);
    }

    function fundMilestone(uint256 _milestoneId) external payable onlyClient contractActive {
        require(_milestoneId < milestones.length, "Invalid milestone");
        Milestone storage m = milestones[_milestoneId];
        require(m.status == MilestoneStatus.Pending, "Not pending");
        require(msg.value == m.amount, "Incorrect amount");
        m.status = MilestoneStatus.Funded;
        totalFunded += msg.value;
        emit MilestoneFunded(_milestoneId, msg.value);
    }

    function submitMilestone(uint256 _milestoneId) external onlyFreelancer contractActive {
        require(_milestoneId < milestones.length, "Invalid milestone");
        Milestone storage m = milestones[_milestoneId];
        require(m.status == MilestoneStatus.Funded, "Not funded");
        m.status = MilestoneStatus.Submitted;
        emit MilestoneSubmitted(_milestoneId);
    }

    function approveMilestone(uint256 _milestoneId) external onlyClient contractActive {
        require(_milestoneId < milestones.length, "Invalid milestone");
        Milestone storage m = milestones[_milestoneId];
        require(m.status == MilestoneStatus.Submitted, "Not submitted");
        m.status = MilestoneStatus.Approved;
        uint256 payment = m.amount;
        totalFunded -= payment;
        (bool success, ) = freelancer.call{value: payment}("");
        require(success, "Transfer failed");
        emit MilestoneApproved(_milestoneId, payment);

        if (_allMilestonesApproved()) {
            contractStatus = ContractStatus.Completed;
        }
    }

    function raiseDispute(uint256 _milestoneId) external contractActive {
        require(msg.sender == client || msg.sender == freelancer, "Not authorized");
        require(_milestoneId < milestones.length, "Invalid milestone");
        Milestone storage m = milestones[_milestoneId];
        require(m.status == MilestoneStatus.Funded || m.status == MilestoneStatus.Submitted, "Cannot dispute");
        m.status = MilestoneStatus.Disputed;
        emit DisputeRaised(_milestoneId);
    }

    function resolveDispute(uint256 _milestoneId, bool _releaseToFreelancer) external onlyArbiter {
        require(_milestoneId < milestones.length, "Invalid milestone");
        Milestone storage m = milestones[_milestoneId];
        require(m.status == MilestoneStatus.Disputed, "Not disputed");

        uint256 amount = m.amount;
        totalFunded -= amount;
        address recipient;

        if (_releaseToFreelancer) {
            m.status = MilestoneStatus.Approved;
            recipient = freelancer;
        } else {
            m.status = MilestoneStatus.Pending;
            m.amount = 0;
            recipient = client;
        }

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Transfer failed");
        emit DisputeResolved(_milestoneId, recipient, amount);
    }

    function cancelContract() external onlyClient contractActive {
        contractStatus = ContractStatus.Cancelled;
        uint256 refund = 0;
        for (uint256 i = 0; i < milestones.length; i++) {
            if (milestones[i].status == MilestoneStatus.Funded) {
                refund += milestones[i].amount;
                milestones[i].status = MilestoneStatus.Pending;
                milestones[i].amount = 0;
            }
        }
        totalFunded -= refund;
        if (refund > 0) {
            (bool success, ) = client.call{value: refund}("");
            require(success, "Refund failed");
        }
        emit ContractCancelled(refund);
    }

    function getMilestoneCount() external view returns (uint256) {
        return milestones.length;
    }

    function _allMilestonesApproved() internal view returns (bool) {
        for (uint256 i = 0; i < milestones.length; i++) {
            if (milestones[i].status != MilestoneStatus.Approved) {
                return false;
            }
        }
        return milestones.length > 0;
    }
}