```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title MyGovernanceToken
 * @dev A very basic ERC20 token for governance purposes.
 *      Simplified for testnet: getVotes returns current balance, no historical snapshots.
 */
contract MyGovernanceToken {
    string public name = "MyGovernanceToken";
    string public symbol = "MGT";
    uint8 public decimals = 18;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => address) public delegates; // Simplified: just stores the delegatee

    uint256 private _totalSupply;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);
    event DelegateVotesChanged(address indexed delegate, uint256 previousBalance, uint256 newBalance);

    constructor(address initialOwner) {
        _mint(initialOwner, 1_000_000 * (10 ** uint256(decimals))); // 1 Million tokens
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 amount) public returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function allowance(address owner, address spender) public view returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public returns (bool) {
        uint256 currentAllowance = _allowances[from][msg.sender];
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
        _approve(from, msg.sender, currentAllowance - amount);
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[from] = fromBalance - amount;
        }
        _balances[to] += amount;

        emit Transfer(from, to, amount);
    }

    function _mint(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: mint to the zero address");

        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Set's `delegatee` as the delegate for `msg.sender`.
     * Simplified: does not update vote power, only sets the delegate.
     */
    function delegate(address delegatee) public {
        address currentDelegate = delegates[msg.sender];
        require(currentDelegate != delegatee, "MyGovernanceToken: already delegated to this address");

        delegates[msg.sender] = delegatee;
        emit DelegateChanged(msg.sender, currentDelegate, delegatee);
        // For testnet, we don't track vote changes on delegation explicitly,
        // as getVotes just returns current balance.
    }

    /**
     * @dev Returns the current number of votes for `account`.
     * Simplified: returns current token balance.
     */
    function getVotes(address account) public view returns (uint256) {
        return balanceOf(account);
    }
}


/**
 * @title MyDAO
 * @dev A basic DAO contract for testnet deployment.
 *      Features: Proposal creation, voting, and direct execution.
 *      Simplifications: No timelock, voting power is current balance, basic error handling.
 */
contract MyDAO {
    // --- State Variables ---
    MyGovernanceToken public immutable governanceToken;

    // Proposal states
    enum ProposalState { Pending, Active, Canceled, Defeated, Succeeded, Executed }
    // Vote types
    enum VoteType { Against, For, Abstain }

    struct Proposal {
        uint256 id;
        address proposer;
        address target;       // Contract to call
        uint256 value;        // Ether to send with the call
        bytes callData;       // Encoded function call
        string description;   // Human-readable description

        uint256 voteStartBlock; // Block number when voting starts
        uint256 voteEndBlock;   // Block number when voting ends

        uint256 forVotes;
        uint256 againstVotes;
        uint256 abstainVotes;
        bool executed;
    }

    mapping(uint256 => Proposal) public proposals;
    uint256 public proposalCount;

    // Mapping to track if an address has voted on a proposal
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    // DAO parameters
    uint256 public immutable votingPeriodBlocks; // Duration of voting in blocks
    uint256 public immutable quorumVotes;        // Minimum total votes required for a proposal to pass
    uint224 public immutable proposalThreshold;  // Minimum token balance required to create a proposal

    // --- Events ---
    event ProposalCreated(
        uint256 id,
        address proposer,
        address target,
        uint256 value,
        bytes callData,
        uint256 voteStartBlock,
        uint256 voteEndBlock,
        string description
    );
    event VoteCast(
        address indexed voter,
        uint256 proposalId,
        VoteType support,
        uint256 votes
    );
    event ProposalExecuted(uint256 proposalId);

    // --- Constructor ---
    constructor(
        address _governanceTokenAddress,
        uint256 _votingPeriodBlocks,
        uint256 _quorumVotes,
        uint256 _proposalThreshold
    ) {
        require(_governanceTokenAddress != address(0), "Invalid governance token address");
        require(_votingPeriodBlocks > 0, "Voting period must be greater than 0");

        governanceToken = MyGovernanceToken(_governanceTokenAddress);
        votingPeriodBlocks = _votingPeriodBlocks;
        quorumVotes = _quorumVotes;
        proposalThreshold = uint224(_proposalThreshold); // Max 2^224 - 1
        proposalCount = 0;
    }

    // --- Core Functions ---

    /**
     * @dev Creates a new proposal.
     * @param _target The address of the contract to call.
     * @param _value The amount of Ether to send with the call.
     * @param _callData The encoded function call (e.g., `abi.encodeWithSignature("transfer(address,uint256)", recipient, amount)`).
     * @param _description A human-readable description of the proposal.
     */
    function createProposal(
        address _target,
        uint256 _value,
        bytes calldata _callData,
        string calldata _description
    ) external returns (uint256 proposalId) {
        require(governanceToken.getVotes(msg.sender) >= proposalThreshold, "MyDAO: Proposer below proposal threshold");

        proposalId = ++proposalCount;
        uint224 currentBlock = uint224(block.number);

        Proposal storage newProposal = proposals[proposalId];
        newProposal.id = proposalId;
        newProposal.proposer = msg.sender;
        newProposal.target = _target;
        newProposal.value = _value;
        newProposal.callData = _callData;
        newProposal.description = _description;
        newProposal.voteStartBlock = currentBlock + 1; // Voting starts next block
        newProposal.voteEndBlock = newProposal.voteStartBlock + votingPeriodBlocks;
        newProposal.executed = false;

        emit ProposalCreated(
            proposalId,
            msg.sender,
            _target,
            _value,
            _callData,
            newProposal.voteStartBlock,
            newProposal.voteEndBlock,
            _description
        );
    }

    /**
     * @dev Returns the current state of a proposal.
     * @param _proposalId The ID of the proposal.
     */
    function state(uint256 _proposalId) public view returns (ProposalState) {
        Proposal storage proposal = proposals[_proposalId];
        require(proposal.id != 0, "MyDAO: Proposal does not exist");

        uint256 currentBlock = block.number;

        if (proposal.executed) {
            return ProposalState.Executed;
        } else if (currentBlock <= proposal.voteStartBlock) {
            return ProposalState.Pending;
        } else if (currentBlock <= proposal.voteEndBlock) {
            return ProposalState.Active;
        } else { // Voting