// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract EscrowPlatform {
    enum Status { Created, InProgress, Disputed, Completed }
    enum Decision { None, BuyerWins, SellerWins }

    struct Milestone {
        uint256 amount;
        bool paid;
        string description;
    }

    struct Dispute {
        address[] parties;
        address[] evidence;
        Decision decision;
        bool resolved;
    }

    struct Contract {
        address buyer;
        address seller;
        address arbiter;
        Milestone[] milestones;
        Dispute dispute;
        Status status;
        uint256 timeout;
    }

    mapping(uint256 => Contract) public contracts;
    uint256 public contractId;

    event ContractCreated(uint256 id, address buyer, address seller, address arbiter, uint256 timeout);
    event MilestonePaid(uint256 id, uint256 milestoneIndex);
    event DisputeRaised(uint256 id);
    event EvidenceSubmitted(uint256 id, address party, address evidence);
    event DisputeResolved(uint256 id, Decision decision);
    event ContractCompleted(uint256 id);

    modifier onlyBuyer(uint256 id) {
        require(msg.sender == contracts[id].buyer, "Not the buyer");
        _;
    }

    modifier onlySeller(uint256 id) {
        require(msg.sender == contracts[id].seller, "Not the seller");
        _;
    }

    modifier onlyArbiter(uint256 id) {
        require(msg.sender == contracts[id].arbiter, "Not the arbiter");
        _;
    }

    modifier onlyContractParticipant(uint256 id) {
        require(
            msg.sender == contracts[id].buyer ||
            msg.sender == contracts[id].seller ||
            msg.sender == contracts[id].arbiter,
            "Not a contract participant"
        );
        _;
    }

    modifier onlyIfDisputed(uint256 id) {
        require(contracts[id].status == Status.Disputed, "Not disputed");
        _;
    }

    modifier onlyIfNotDisputed(uint256 id) {
        require(contracts[id].status != Status.Disputed, "Disputed");
        _;
    }

    modifier onlyIfNotCompleted(uint256 id) {
        require(contracts[id].status != Status.Completed, "Completed");
        _;
    }

    function createContract(
        address _seller,
        address _arbiter,
        Milestone[] memory _milestones,
        uint256 _timeout
    ) external payable {
        require(_milestones.length > 0, "No milestones provided");
        require(msg.value > 0, "No funds provided");
        require(_timeout > 0, "Timeout must be greater than 0");

        uint256 totalAmount = 0;
        for (uint256 i = 0; i < _milestones.length; i++) {
            totalAmount += _milestones[i].amount;
        }
        require(msg.value == totalAmount, "Funds do not match milestone amounts");

        contractId++;
        contracts[contractId] = Contract({
            buyer: msg.sender,
            seller: _seller,
            arbiter: _arbiter,
            milestones: _milestones,
            dispute: Dispute({parties: new address[](0), evidence: new address[](0), decision: Decision.None, resolved: false}),
            status: Status.Created,
            timeout: block.timestamp + _timeout
        });

        emit ContractCreated(contractId, msg.sender, _seller, _arbiter, _timeout);
    }

    function payMilestone(uint256 id, uint256 milestoneIndex) external onlySeller(id) onlyIfNotDisputed(id) onlyIfNotCompleted(id) {
        require(milestoneIndex < contracts[id].milestones.length, "Invalid milestone index");
        Milestone storage milestone = contracts[id].milestones[milestoneIndex];
        require(!milestone.paid, "Milestone already paid");

        milestone.paid = true;
        payable(contracts[id].seller).transfer(milestone.amount);

        emit MilestonePaid(id, milestoneIndex);
    }

    function raiseDispute(uint256 id) external onlyIfNotDisputed(id) onlyIfNotCompleted(id) {
        contracts[id].status = Status.Disputed;
        contracts[id].dispute.parties = new address[](2);
        contracts[id].dispute.parties[0] = contracts[id].buyer;
        contracts[id].dispute.parties[1] = contracts[id].seller;

        emit DisputeRaised(id);
    }

    function submitEvidence(uint256 id) external onlyContractParticipant(id) onlyIfDisputed(id) {
        contracts[id].dispute.evidence.push(msg.sender);

        emit EvidenceSubmitted(id, msg.sender, msg.sender);
    }

    function resolveDispute(uint256 id, Decision _decision) external onlyArbiter(id) onlyIfDisputed(id) {
        contracts[id].dispute.decision = _decision;
        contracts[id].dispute.resolved = true;

        if (_decision == Decision.BuyerWins) {
            payable(contracts[id].buyer).transfer(address(this).balance);
        } else if (_decision == Decision.SellerWins) {
            payable(contracts[id].seller).transfer(address(this).balance);
        }

        contracts[id].status = Status.Completed;

        emit DisputeResolved(id, _decision);
    }

    function completeContract(uint256 id) external onlyIfNotDisputed(id) onlyIfNotCompleted(id) {
        require(block.timestamp > contracts[id].timeout, "Timeout not reached");
        payable(contracts[id].seller).transfer(address(this).balance);
        contracts[id].status = Status.Completed;

        emit ContractCompleted(id);
    }
}