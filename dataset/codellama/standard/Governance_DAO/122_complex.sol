// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Governor {
    // Proposal structure
    struct Proposal {
        address proposer;
        uint256 startBlock;
        uint256 endBlock;
        uint256 votesFor;
        uint256 votesAgainst;
        mapping(address => bool) voted;
        mapping(address => uint256) votes;
    }

    // Proposal list
    Proposal[] public proposals;

    // Timelock contract address
    address public timelock;

    // EIP-712 vote signature
    bytes32 public constant EIP712DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 public constant EIP712_TYPEHASH = keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

    constructor(address _timelock) public {
        timelock = _timelock;
    }

    // Create a new proposal
    function createProposal(string memory _description, uint256 _voteStartBlock, uint256 _voteEndBlock) public {
        Proposal memory proposal = Proposal({
            proposer: msg.sender,
            startBlock: _voteStartBlock,
            endBlock: _voteEndBlock,
            votesFor: 0,
            votesAgainst: 0
        });
        proposals.push(proposal);
    }

    // Vote on a proposal
    function vote(uint256 _proposalId, bool _support) public {
        Proposal storage proposal = proposals[_proposalId];
        require(proposal.startBlock <= block.number && block.number <= proposal.endBlock, "Voting is not active");
        require(!proposal.voted[msg.sender], "Already voted");
        proposal.voted[msg.sender] = true;
        if (_support) {
            proposal.votesFor += 1;
        } else {
            proposal.votesAgainst += 1;
        }
    }

    // Cancel a proposal
    function cancelProposal(uint256 _proposalId) public {
        Proposal storage proposal = proposals[_proposalId];
        require(msg.sender == proposal.proposer, "Only the proposer can cancel the proposal");
        require(proposal.startBlock > block.number, "Cannot cancel a proposal that has already started voting");
        proposal.startBlock = 0;
        proposal.endBlock = 0;
    }

    // Get the current vote count for a proposal
    function getVoteCount(uint256 _proposalId) public view returns (uint256) {
        Proposal storage proposal = proposals[_proposalId];
        return proposal.votesFor + proposal.votesAgainst;
    }

    // Get the current vote status for a proposal
    function getVoteStatus(uint256 _proposalId) public view returns (bool) {
        Proposal storage proposal = proposals[_proposalId];
        return proposal.votesFor > proposal.votesAgainst;
    }

    // Get the current vote snapshot for a proposal
    function getVoteSnapshot(uint256 _proposalId) public view returns (mapping(address => bool) memory) {
        Proposal storage proposal = proposals[_proposalId];
        return proposal.voted;
    }

    // Get the current timelock address
    function getTimelock() public view returns (address) {
        return timelock;
    }

    // Set a new timelock address
    function setTimelock(address _timelock) public {
        require(msg.sender == timelock, "Only the current timelock can set a new timelock");
        timelock = _timelock;
    }

    // EIP-712 vote signature
    function getEIP712Signature(address _signer, uint256 _proposalId, bool _support) public view returns (bytes memory) {
        Proposal storage proposal = proposals[_proposalId];
        require(proposal.startBlock <= block.number && block.number <= proposal.endBlock, "Voting is not active");
        bytes32 typeHash = keccak256(abi.encodePacked("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"));
        bytes32 structHash = keccak256(abi.encodePacked(typeHash, _signer, _proposalId, _support));
        bytes32 messageHash = keccak256(abi.encodePacked(structHash, proposal.startBlock, proposal.endBlock));
        return messageHash;
    }

    // EIP-712 vote signature verification
    function verifyEIP712Signature(address _signer, uint256 _proposalId, bool _support, bytes memory _signature) public view returns (bool) {
        Proposal storage proposal = proposals[_proposalId];
        require(proposal.startBlock <= block.number && block.number <= proposal.endBlock, "Voting is not active");
        bytes32 typeHash = keccak256(abi.encodePacked("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"));
        bytes32 structHash = keccak256(abi.encodePacked(typeHash, _signer, _proposalId, _support));
        bytes32 messageHash = keccak256(abi.encodePacked(structHash, proposal.startBlock, proposal.endBlock));
        bytes32 hash = keccak256(abi.encodePacked(messageHash));
        return hash == _signature;
    }
}