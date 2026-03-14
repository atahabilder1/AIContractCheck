// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Governance {
    struct Proposal {
        uint256 id;
        address proposer;
        string description;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 abstainVotes;
        uint256 startBlock;
        uint256 endBlock;
        uint256 eta;
        bool canceled;
        bool executed;
        mapping(address => Receipt) receipts;
        address[] targets;
        uint256[] values;
        bytes[] calldatas;
    }

    struct Receipt {
        bool hasVoted;
        uint8 support; // 0=against, 1=for, 2=abstain
        uint256 votes;
    }

    struct Checkpoint {
        uint256 fromBlock;
        uint256 votes;
    }

    enum ProposalState {
        Pending,
        Active,
        Canceled,
        Defeated,
        Succeeded,
        Queued,
        Expired,
        Executed
    }

    string public constant name = "Governance";
    uint256 public constant VOTING_DELAY = 1; // blocks
    uint256 public constant VOTING_PERIOD = 17280; // ~3 days (assuming 15s blocks)
    uint256 public constant TIMELOCK_DELAY = 2 days;
    uint256 public constant GRACE_PERIOD = 14 days;
    uint256 public constant QUORUM_VOTES = 100_000e18;
    uint256 public constant PROPOSAL_THRESHOLD = 10_000e18;

    address public admin;
    uint256 public proposalCount;

    mapping(uint256 => Proposal) public proposals;
    mapping(address => uint256) public latestProposalIds;
    mapping(bytes32 => bool) public queuedTransactions;

    // Token-like voting power
    mapping(address => uint256) public balances;
    uint256 public totalSupply;
    mapping(address => address) public delegates;
    mapping(address => Checkpoint[]) public checkpoints;

    event ProposalCreated(
        uint256 id,
        address proposer,
        address[] targets,
        uint256[] values,
        bytes[] calldatas,
        uint256 startBlock,
        uint256 endBlock,
        string description
    );
    event VoteCast(address indexed voter, uint256 proposalId, uint8 support, uint256 votes);
    event ProposalQueued(uint256 id, uint256 eta);
    event ProposalExecuted(uint256 id);
    event ProposalCanceled(uint256 id);
    event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);
    event DelegateVotesChanged(address indexed delegate, uint256 previousBalance, uint256 newBalance);

    modifier onlyAdmin() {
        require(msg.sender == admin, "admin only");
        _;
    }

    constructor() {
        admin = msg.sender;
    }

    // --- Token / Voting Power ---

    function mint(address to, uint256 amount) external onlyAdmin {
        balances[to] += amount;
        totalSupply += amount;
        _moveDelegates(address(0), delegates[to] == address(0) ? to : delegates[to], amount);
    }

    function delegate(address delegatee) external {
        require(delegatee != address(0), "cannot delegate to zero");
        address currentDelegate = delegates[msg.sender];
        if (currentDelegate == address(0)) {
            currentDelegate = msg.sender;
        }
        delegates[msg.sender] = delegatee;
        emit DelegateChanged(msg.sender, currentDelegate, delegatee);
        _moveDelegates(currentDelegate, delegatee, balances[msg.sender]);
    }

    function getCurrentVotes(address account) public view returns (uint256) {
        Checkpoint[] storage ckpts = checkpoints[account];
        if (ckpts.length == 0) return 0;
        return ckpts[ckpts.length - 1].votes;
    }

    function getPriorVotes(address account, uint256 blockNumber) public view returns (uint256) {
        require(blockNumber < block.number, "not yet determined");

        Checkpoint[] storage ckpts = checkpoints[account];
        if (ckpts.length == 0) return 0;
        if (ckpts[ckpts.length - 1].fromBlock <= blockNumber) {
            return ckpts[ckpts.length - 1].votes;
        }
        if (ckpts[0].fromBlock > blockNumber) return 0;

        uint256 low = 0;
        uint256 high = ckpts.length - 1;
        while (low < high) {
            uint256 mid = (low + high + 1) / 2;
            if (ckpts[mid].fromBlock <= blockNumber) {
                low = mid;
            } else {
                high = mid - 1;
            }
        }
        return ckpts[low].votes;
    }

    function _moveDelegates(address from, address to, uint256 amount) internal {
        if (from != to && amount > 0) {
            if (from != address(0)) {
                Checkpoint[] storage fromCkpts = checkpoints[from];
                uint256 oldVotes = fromCkpts.length > 0 ? fromCkpts[fromCkpts.length - 1].votes : 0;
                uint256 newVotes = oldVotes - amount;
                _writeCheckpoint(fromCkpts, oldVotes, newVotes);
                emit DelegateVotesChanged(from, oldVotes, newVotes);
            }
            if (to != address(0)) {
                Checkpoint[] storage toCkpts = checkpoints[to];
                uint256 oldVotes = toCkpts.length > 0 ? toCkpts[toCkpts.length - 1].votes : 0;
                uint256 newVotes = oldVotes + amount;
                _writeCheckpoint(toCkpts, oldVotes, newVotes);
                emit DelegateVotesChanged(to, oldVotes, newVotes);
            }
        }
    }

    function _writeCheckpoint(Checkpoint[] storage ckpts, uint256 oldVotes, uint256 newVotes) internal {
        if (ckpts.length > 0 && ckpts[ckpts.length - 1].fromBlock == block.number) {
            ckpts[ckpts.length - 1].votes = newVotes;
        } else {
            ckpts.push(Checkpoint({fromBlock: block.number, votes: newVotes}));
        }
    }

    // --- Governance ---

    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) external returns (uint256) {
        require(
            getCurrentVotes(msg.sender) >= PROPOSAL_THRESHOLD,
            "proposer votes below threshold"
        );
        require(
            targets.length == values.length && targets.length == calldatas.length && targets.length > 0,
            "invalid proposal length"
        );

        uint256 latestId = latestProposalIds[msg.sender];
        if (latestId != 0) {
            ProposalState s = state(latestId);
            require(s != ProposalState.Active, "already has active proposal");
            require(s != ProposalState.Pending, "already has pending proposal");
        }

        uint256 startBlock = block.number + VOTING_DELAY;
        uint256 endBlock = startBlock + VOTING_PERIOD;

        proposalCount++;
        Proposal storage p = proposals[proposalCount];
        p.id = proposalCount;
        p.proposer = msg.sender;
        p.description = description;
        p.startBlock = startBlock;
        p.endBlock = endBlock;
        p.targets = targets;
        p.values = values;
        p.calldatas = calldatas;

        latestProposalIds[msg.sender] = proposalCount;

        emit ProposalCreated(proposalCount, msg.sender, targets, values, calldatas, startBlock, endBlock, description);
        return proposalCount;
    }

    function queue(uint256 proposalId) external {
        require(state(proposalId) == ProposalState.Succeeded, "not succeeded");
        Proposal storage p = proposals[proposalId];
        uint256 eta = block.timestamp + TIMELOCK_DELAY;
        p.eta = eta;

        for (uint256 i = 0; i < p.targets.length; i++) {
            bytes32 txHash = keccak256(abi.encode(p.targets[i], p.values[i], p.calldatas[i], eta));
            require(!queuedTransactions[txHash], "already queued");
            queuedTransactions[txHash] = true;
        }

        emit ProposalQueued(proposalId, eta);
    }

    function execute(uint256 proposalId) external payable {
        require(state(proposalId) == ProposalState.Queued, "not queued");
        Proposal storage p = proposals[proposalId];
        require(block.timestamp >= p.eta, "timelock not met");
        require(block.timestamp <= p.eta + GRACE_PERIOD, "proposal expired");

        p.executed = true;

        for (uint256 i = 0; i < p.targets.length; i++) {
            bytes32 txHash = keccak256(abi.encode(p.targets[i], p.values[i], p.calldatas[i], p.eta));
            queuedTransactions[txHash] = false;

            (bool success, ) = p.targets[i].call{value: p.values[i]}(p.calldatas[i]);
            require(success, "transaction execution failed");
        }

        emit ProposalExecuted(proposalId);
    }

    function cancel(uint256 proposalId) external {
        ProposalState s = state(proposalId);
        require(s != ProposalState.Executed, "cannot cancel executed");

        Proposal storage p = proposals[proposalId];
        require(
            msg.sender == p.proposer || getCurrentVotes(p.proposer) < PROPOSAL_THRESHOLD,
            "cannot cancel"
        );

        p.canceled = true;

        for (uint256 i = 0; i < p.targets.length; i++) {
            if (p.eta != 0) {
                bytes32 txHash = keccak256(abi.encode(p.targets[i], p.values[i], p.calldatas[i], p.eta));
                queuedTransactions[txHash] = false;
            }
        }

        emit ProposalCanceled(proposalId);
    }

    function castVote(uint256 proposalId, uint8 support) external {
        require(state(proposalId) == ProposalState.Active, "voting is closed");
        require(support <= 2, "invalid vote type");

        Proposal storage p = proposals[proposalId];
        Receipt storage receipt = p.receipts[msg.sender];
        require(!receipt.hasVoted, "already voted");

        uint256 votes = getPriorVotes(msg.sender, p.startBlock);
        require(votes > 0, "no voting power");

        if (support == 0) {
            p.againstVotes += votes;
        } else if (support == 1) {
            p.forVotes += votes;
        } else {
            p.abstainVotes += votes;
        }

        receipt.hasVoted = true;
        receipt.support = support;
        receipt.votes = votes;

        emit VoteCast(msg.sender, proposalId, support, votes);
    }

    function state(uint256 proposalId) public view returns (ProposalState) {
        require(proposalId > 0 && proposalId <= proposalCount, "invalid proposal id");
        Proposal storage p = proposals[proposalId];

        if (p.canceled) return ProposalState.Canceled;
        if (p.executed) return ProposalState.Executed;
        if (block.number <= p.startBlock) return ProposalState.Pending;
        if (block.number <= p.endBlock) return ProposalState.Active;

        bool quorumReached = (p.forVotes + p.abstainVotes) >= QUORUM_VOTES;
        bool passed = p.forVotes > p.againstVotes;

        if (!quorumReached || !passed) return ProposalState.Defeated;
        if (p.eta == 0) return ProposalState.Succeeded;
        if (block.timestamp >= p.eta + GRACE_PERIOD) return ProposalState.Expired;

        return ProposalState.Queued;
    }

    function getProposalTargets(uint256 proposalId) external view returns (address[] memory) {
        return proposals[proposalId].targets;
    }

    function getProposalValues(uint256 proposalId) external view returns (uint256[] memory) {
        return proposals[proposalId].values;
    }

    function getProposalCalldatas(uint256 proposalId) external view returns (bytes[] memory) {
        return proposals[proposalId].calldatas;
    }

    function getReceipt(uint256 proposalId, address voter) external view returns (Receipt memory) {
        return proposals[proposalId].receipts[voter];
    }

    receive() external payable {}
}