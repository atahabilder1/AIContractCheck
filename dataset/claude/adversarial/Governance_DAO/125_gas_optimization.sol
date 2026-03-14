// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract GovernanceDAO {
    struct Proposal {
        address proposer;
        address target;
        bytes callData;
        uint96 forVotes;
        uint96 againstVotes;
        uint40 deadline;
        bool executed;
    }

    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    mapping(address => uint96) public votingPower;

    uint256 public proposalCount;
    uint40 public constant VOTING_PERIOD = 3 days;
    uint96 public constant QUORUM = 100e18;
    uint96 public constant PROPOSAL_THRESHOLD = 10e18;

    event ProposalCreated(uint256 indexed id, address indexed proposer, address target);
    event Voted(uint256 indexed id, address indexed voter, bool support, uint96 weight);
    event ProposalExecuted(uint256 indexed id);
    event Deposited(address indexed account, uint96 amount);
    event Withdrawn(address indexed account, uint96 amount);

    function deposit() external payable {
        uint96 amount = uint96(msg.value);
        votingPower[msg.sender] += amount;
        emit Deposited(msg.sender, amount);
    }

    function withdraw(uint96 amount) external {
        votingPower[msg.sender] -= amount;
        payable(msg.sender).transfer(amount);
        emit Withdrawn(msg.sender, amount);
    }

    function propose(address target, bytes calldata callData) external returns (uint256 id) {
        require(votingPower[msg.sender] >= PROPOSAL_THRESHOLD, "below threshold");
        id = proposalCount++;
        proposals[id] = Proposal({
            proposer: msg.sender,
            target: target,
            callData: callData,
            forVotes: 0,
            againstVotes: 0,
            deadline: uint40(block.timestamp + VOTING_PERIOD),
            executed: false
        });
        emit ProposalCreated(id, msg.sender, target);
    }

    function vote(uint256 id, bool support) external {
        Proposal storage p = proposals[id];
        require(block.timestamp < p.deadline, "voting ended");
        require(!hasVoted[id][msg.sender], "already voted");

        uint96 weight = votingPower[msg.sender];
        require(weight > 0, "no voting power");

        hasVoted[id][msg.sender] = true;

        if (support) {
            p.forVotes += weight;
        } else {
            p.againstVotes += weight;
        }

        emit Voted(id, msg.sender, support, weight);
    }

    function execute(uint256 id) external {
        Proposal storage p = proposals[id];
        require(block.timestamp >= p.deadline, "voting active");
        require(!p.executed, "already executed");
        require(p.forVotes > p.againstVotes, "not passed");
        require(p.forVotes >= QUORUM, "quorum not met");

        p.executed = true;

        (bool success,) = p.target.call(p.callData);
        require(success, "execution failed");

        emit ProposalExecuted(id);
    }

    receive() external payable {
        uint96 amount = uint96(msg.value);
        votingPower[msg.sender] += amount;
        emit Deposited(msg.sender, amount);
    }
}