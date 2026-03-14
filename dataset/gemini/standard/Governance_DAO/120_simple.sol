// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
}

contract BasicDAO {
    IERC20 public immutable votingToken;

    struct Proposal {
        uint256 id;
        string description;
        address creator;
        uint256 startTime;
        uint256 endTime;
        uint256 forVotes;
        uint256 againstVotes;
        bool executed;
        mapping(address => bool) hasVoted; // Tracks if an address has voted on this proposal
    }

    uint256 public nextProposalId;
    mapping(uint256 => Proposal) public proposals;

    uint256 public constant VOTING_PERIOD = 7 days; // Proposals last for 7 days

    event ProposalCreated(
        uint256 proposalId,
        address indexed creator,
        string description,
        uint256 startTime,
        uint256 endTime
    );
    event Voted(
        uint256 proposalId,
        address indexed voter,
        bool support,
        uint256 votingPower
    );
    event ProposalExecuted(uint256 proposalId, bool passed);

    constructor(address _votingTokenAddress) {
        require(_votingTokenAddress != address(0), "Invalid token address");
        votingToken = IERC20(_votingTokenAddress);
    }

    /**
     * @notice Creates a new proposal.
     * @param _description A description of the proposal.
     * @return The ID of the newly created proposal.
     */
    function createProposal(string calldata _description) external returns (uint256) {
        uint256 proposalId = nextProposalId;
        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + VOTING_PERIOD;

        proposals[proposalId] = Proposal({
            id: proposalId,
            description: _description,
            creator: msg.sender,
            startTime: startTime,
            endTime: endTime,
            forVotes: 0,
            againstVotes: 0,
            executed: false
        });

        nextProposalId++;

        emit ProposalCreated(proposalId, msg.sender, _description, startTime, endTime);
        return proposalId;
    }

    /**
     * @notice Allows a token holder to vote on a proposal.
     * Voting power is determined by the caller's balance of the voting token at the time of voting.
     * @param _proposalId The ID of the proposal to vote on.
     * @param _support True for a 'for' vote, false for an 'against' vote.
     */
    function vote(uint256 _proposalId, bool _support) external {
        Proposal storage proposal = proposals[_proposalId];

        require(proposal.id == _proposalId, "Proposal does not exist");
        require(block.timestamp >= proposal.startTime, "Voting has not started yet");
        require(block.timestamp <= proposal.endTime, "Voting period has ended");
        require(!proposal.executed, "Proposal already executed");
        require(!proposal.hasVoted[msg.sender], "Already voted on this proposal");

        uint256 voterBalance = votingToken.balanceOf(msg.sender);
        require(voterBalance > 0, "No voting power (token balance is zero)");

        proposal.hasVoted[msg.sender] = true;

        if (_support) {
            proposal.forVotes += voterBalance;
        } else {
            proposal.againstVotes += voterBalance;
        }

        emit Voted(_proposalId, msg.sender, _support, voterBalance);
    }

    /**
     * @notice Executes a proposal after its voting period has ended.
     * A proposal passes if 'for' votes are greater than 'against' votes.
     * @param _proposalId The ID of the proposal to execute.
     */
    function executeProposal(uint256 _proposalId) external {
        Proposal storage proposal = proposals[_proposalId];

        require(proposal.id == _proposalId, "Proposal does not exist");
        require(block.timestamp > proposal.endTime, "Voting period has not ended yet");
        require(!proposal.executed, "Proposal already executed");

        proposal.executed = true; // Mark as executed to prevent re-execution

        bool passed = proposal.forVotes > proposal.againstVotes;

        // In a more complex DAO, this is where the actual logic for the proposal
        // (e.g., sending tokens, calling another contract function) would be implemented,
        // often via a separate 'Governor' contract or by directly interacting with target contracts.
        // For this basic DAO, we just record the outcome.

        emit ProposalExecuted(_proposalId, passed);
    }

    /**
     * @notice Retrieves details of a specific proposal.
     * @param _proposalId The ID of the proposal to retrieve.
     * @return A tuple containing proposal details.
     */
    function getProposal(uint256 _proposalId)
        public
        view
        returns (
            uint256 id,
            string memory description,
            address creator,
            uint256 startTime,
            uint256 endTime,
            uint256 forVotes,
            uint256 againstVotes,
            bool executed,
            bool hasVotedByCaller
        )
    {
        Proposal storage proposal = proposals[_proposalId];
        require(proposal.id == _proposalId, "Proposal does not exist"); // Ensure it's a valid proposal

        id = proposal.id;
        description = proposal.description;
        creator = proposal.creator;
        startTime = proposal.startTime;
        endTime = proposal.endTime;
        forVotes = proposal.forVotes;
        againstVotes = proposal.againstVotes;
        executed = proposal.executed;
        hasVotedByCaller = proposal.hasVoted[msg.sender];
    }
}