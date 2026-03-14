// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract QuadraticVotingDAO {
    mapping(address => uint256) public tokenBalances;
    mapping(bytes32 => mapping(address => uint256)) public votes;
    mapping(bytes32 => int256) public proposalResults;

    event Voted(address voter, bytes32 proposalId, int256 choice, uint256 votingPower);
    event ProposalResultUpdated(bytes32 proposalId, int256 result);

    function depositTokens(uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0");
        tokenBalances[msg.sender] += amount;
    }

    function withdrawTokens(uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0");
        require(tokenBalances[msg.sender] >= amount, "Insufficient balance");
        tokenBalances[msg.sender] -= amount;
    }

    function vote(bytes32 proposalId, int256 choice) external {
        require(choice == -1 || choice == 1, "Choice must be -1 or 1");
        uint256 votingPower = calculateVotingPower(msg.sender);
        require(votingPower > 0, "No voting power");

        proposalResults[proposalId] += choice * int256(votingPower);
        votes[proposalId][msg.sender] = votingPower;

        emit Voted(msg.sender, proposalId, choice, votingPower);
        emit ProposalResultUpdated(proposalId, proposalResults[proposalId]);
    }

    function calculateVotingPower(address voter) public view returns (uint256) {
        return uint256(sqrt(tokenBalances[voter]));
    }

    function sqrt(uint256 x) internal pure returns (uint256) {
        if (x == 0) return 0;
        uint256 n = (x / 2) + 1;
        uint256 n1 = (n + (x / n)) / 2;
        while (n1 < n) {
            n = n1;
            n1 = (n + (x / n)) / 2;
        }
        return n;
    }
}