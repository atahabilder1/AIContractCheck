// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract GovernorAlpha is EIP712 {
    using ECDSA for bytes32;

    string public constant name = "Compound Governor Alpha";
    bytes32 public constant BALLOT_TYPEHASH = keccak256("Ballot(uint256 proposalId,uint8 support)");

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

    struct Proposal {
        uint256 id;
        address proposer;
        uint256 eta;
        address[] targets;
        uint256[] values;
        string[] signatures;
        bytes[] calldatas;
        uint256 startBlock;
        uint256 endBlock;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 abstainVotes;
        bool canceled;
        bool executed;
        mapping(address => Receipt) receipts;
    }

    struct Receipt {
        bool hasVoted;
        uint8 support;
        uint256 votes;
    }

    struct ProposalInfo {
        uint256 id;
        address proposer;
        uint256 eta;
        uint256 startBlock;
        uint256 endBlock;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 abstainVotes;
        bool canceled;
        bool executed;
    }

    ERC20Votes public immutable token;
    Timelock public immutable timelock;

    uint256 public votingDelay;
    uint256 public votingPeriod;
    uint256 public proposalThreshold;
    uint256 public quorumVotes;

    uint256 public proposalCount;
    mapping(uint256 => Proposal) public proposals;
    mapping(address => uint256) public latestProposalIds;

    event ProposalCreated(
        uint256 id,
        address proposer,
        address[] targets,
        uint256[] values,
        string[] signatures,
        bytes[] calldatas,
        uint256 startBlock,
        uint256 endBlock,
        string description
    );
    event VoteCast(address indexed voter, uint256 proposalId, uint8 support, uint256 votes, string reason);
    event ProposalCanceled(uint256 id);
    event ProposalQueued(uint256 id, uint256 eta);
    event ProposalExecuted(uint256 id);

    constructor(
        address token_,
        address payable timelock_,
        uint256 votingDelay_,
        uint256 votingPeriod_,
        uint256 proposalThreshold_,
        uint256 quorumVotes_
    ) EIP712(name, "1") {
        token = ERC20Votes(token_);
        timelock = Timelock(timelock_);
        votingDelay = votingDelay_;
        votingPeriod = votingPeriod_;
        proposalThreshold = proposalThreshold_;
        quorumVotes = quorumVotes_;
    }

    function propose(
        address[] memory targets,
        uint256[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas,
        string memory description
    ) external returns (uint256) {
        require(
            token.getPastVotes(msg.sender, block.number - 1) >= proposalThreshold,
            "Governor: below proposal threshold"
        );
        require(
            targets.length == values.length &&
            targets.length == signatures.length &&
            targets.length == calldatas.length,
            "Governor: arity mismatch"
        );
        require(targets.length > 0, "Governor: empty proposal");

        uint256 latestId = latestProposalIds[msg.sender];
        if (latestId != 0) {
            ProposalState s = state(latestId);
            require(s != ProposalState.Active, "Governor: already active proposal");
            require(s != ProposalState.Pending, "Governor: already pending proposal");
        }

        uint256 startBlock = block.number + votingDelay;
        uint256 endBlock = startBlock + votingPeriod;

        proposalCount++;
        uint256 newProposalId = proposalCount;

        Proposal storage p = proposals[newProposalId];
        p.id = newProposalId;
        p.proposer = msg.sender;
        p.targets = targets;
        p.values = values;
        p.signatures = signatures;
        p.calldatas = calldatas;
        p.startBlock = startBlock;
        p.endBlock = endBlock;

        latestProposalIds[msg.sender] = newProposalId;

        emit ProposalCreated(newProposalId, msg.sender, targets, values, signatures, calldatas, startBlock, endBlock, description);
        return newProposalId;
    }

    function queue(uint256 proposalId) external {
        require(state(proposalId) == ProposalState.Succeeded, "Governor: not succeeded");
        Proposal storage p = proposals[proposalId];
        uint256 eta = block.timestamp + timelock.delay();
        p.eta = eta;
        for (uint256 i = 0; i < p.targets.length; i++) {
            bytes memory callData = _encodeCalldata(p.signatures[i], p.calldatas[i]);
            timelock.queueTransaction(p.targets[i], p.values[i], callData, eta);
        }
        emit ProposalQueued(proposalId, eta);
    }

    function execute(uint256 proposalId) external payable {
        require(state(proposalId) == ProposalState.Queued, "Governor: not queued");
        Proposal storage p = proposals[proposalId];
        p.executed = true;
        for (uint256 i = 0; i < p.targets.length; i++) {
            bytes memory callData = _encodeCalldata(p.signatures[i], p.calldatas[i]);
            timelock.executeTransaction{value: p.values[i]}(p.targets[i], p.values[i], callData, p.eta);
        }
        emit ProposalExecuted(proposalId);
    }

    function cancel(uint256 proposalId) external {
        ProposalState s = state(proposalId);
        require(s != ProposalState.Executed, "Governor: cannot cancel executed");

        Proposal storage p = proposals[proposalId];
        require(
            msg.sender == p.proposer ||
            token.getPastVotes(p.proposer, block.number - 1) < proposalThreshold,
            "Governor: cannot cancel"
        );

        p.canceled = true;
        for (uint256 i = 0; i < p.targets.length; i++) {
            bytes memory callData = _encodeCalldata(p.signatures[i], p.calldatas[i]);
            timelock.cancelTransaction(p.targets[i], p.values[i], callData, p.eta);
        }
        emit ProposalCanceled(proposalId);
    }

    function castVote(uint256 proposalId, uint8 support) external {
        _castVote(msg.sender, proposalId, support, "");
    }

    function castVoteWithReason(uint256 proposalId, uint8 support, string calldata reason) external {
        _castVote(msg.sender, proposalId, support, reason);
    }

    function castVoteBySig(uint256 proposalId, uint8 support, uint8 v, bytes32 r, bytes32 s) external {
        bytes32 structHash = keccak256(abi.encode(BALLOT_TYPEHASH, proposalId, support));
        bytes32 digest = _hashTypedDataV4(structHash);
        address signer = ECDSA.recover(digest, v, r, s);
        _castVote(signer, proposalId, support, "");
    }

    function _castVote(address voter, uint256 proposalId, uint8 support, string memory reason) internal {
        require(state(proposalId) == ProposalState.Active, "Governor: voting closed");
        require(support <= 2, "Governor: invalid vote type");

        Proposal storage p = proposals[proposalId];
        Receipt storage receipt = p.receipts[voter];
        require(!receipt.hasVoted, "Governor: already voted");

        uint256 votes = token.getPastVotes(voter, p.startBlock);

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

        emit VoteCast(voter, proposalId, support, votes, reason);
    }

    function state(uint256 proposalId) public view returns (ProposalState) {
        require(proposalId > 0 && proposalId <= proposalCount, "Governor: invalid proposal id");
        Proposal storage p = proposals[proposalId];

        if (p.canceled) return ProposalState.Canceled;
        if (p.executed) return ProposalState.Executed;
        if (block.number <= p.startBlock) return ProposalState.Pending;
        if (block.number <= p.endBlock) return ProposalState.Active;
        if (p.forVotes <= p.againstVotes || p.forVotes + p.abstainVotes < quorumVotes) return ProposalState.Defeated;
        if (p.eta == 0) return ProposalState.Succeeded;
        if (block.timestamp >= p.eta + timelock.GRACE_PERIOD()) return ProposalState.Expired;
        return ProposalState.Queued;
    }

    function getActions(uint256 proposalId)
        external
        view
        returns (
            address[] memory targets,
            uint256[] memory values,
            string[] memory signatures,
            bytes[] memory calldatas
        )
    {
        Proposal storage p = proposals[proposalId];
        return (p.targets, p.values, p.signatures, p.calldatas);
    }

    function getReceipt(uint256 proposalId, address voter) external view returns (Receipt memory) {
        return proposals[proposalId].receipts[voter];
    }

    function getProposalInfo(uint256 proposalId) external view returns (ProposalInfo memory) {
        Proposal storage p = proposals[proposalId];
        return ProposalInfo({
            id: p.id,
            proposer: p.proposer,
            eta: p.eta,
            startBlock: p.startBlock,
            endBlock: p.endBlock,
            forVotes: p.forVotes,
            againstVotes: p.againstVotes,
            abstainVotes: p.abstainVotes,
            canceled: p.canceled,
            executed: p.executed
        });
    }

    function _encodeCalldata(string memory sig, bytes memory data) internal pure returns (bytes memory) {
        if (bytes(sig).length == 0) {
            return data;
        }
        return abi.encodePacked(bytes4(keccak256(bytes(sig))), data);
    }
}

contract Timelock {
    uint256 public constant GRACE_PERIOD = 14 days;
    uint256 public constant MINIMUM_DELAY = 2 days;
    uint256 public constant MAXIMUM_DELAY = 30 days;

    address public admin;
    address public pendingAdmin;
    uint256 public delay;

    mapping(bytes32 => bool) public queuedTransactions;

    event NewAdmin(address indexed newAdmin);
    event NewPendingAdmin(address indexed newPendingAdmin);
    event NewDelay(uint256 indexed newDelay);
    event QueueTransaction(bytes32 indexed txHash, address indexed target, uint256 value, bytes data, uint256 eta);
    event CancelTransaction(bytes32 indexed txHash, address indexed target, uint256 value, bytes data, uint256 eta);
    event ExecuteTransaction(bytes32 indexed txHash, address indexed target, uint256 value, bytes data, uint256 eta);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Timelock: admin only");
        _;
    }

    modifier onlyTimelock() {
        require(msg.sender == address(this), "Timelock: call must come from Timelock");
        _;
    }

    constructor(address admin_, uint256 delay_) {
        require(delay_ >= MINIMUM_DELAY && delay_ <= MAXIMUM_DELAY, "Timelock: invalid delay");
        admin = admin_;
        delay = delay_;
    }

    receive() external payable {}

    function setDelay(uint256 delay_) external onlyTimelock {
        require(delay_ >= MINIMUM_DELAY && delay_ <= MAXIMUM_DELAY, "Timelock: invalid delay");
        delay = delay_;
        emit NewDelay(delay_);
    }

    function acceptAdmin() external {
        require(msg.sender == pendingAdmin, "Timelock: not pending admin");
        admin = msg.sender;
        pendingAdmin = address(0);
        emit NewAdmin(msg.sender);
    }

    function setPendingAdmin(address pendingAdmin_) external onlyTimelock {
        pendingAdmin = pendingAdmin_;
        emit NewPendingAdmin(pendingAdmin_);
    }

    function queueTransaction(
        address target,
        uint256 value,
        bytes memory data,
        uint256 eta
    ) external onlyAdmin returns (bytes32) {
        require(eta >= block.timestamp + delay, "Timelock: eta too soon");
        bytes32 txHash = keccak256(abi.encode(target, value, data, eta));
        queuedTransactions[txHash] = true;
        emit QueueTransaction(txHash, target, value, data, eta);
        return txHash;
    }

    function cancelTransaction(
        address target,
        uint256 value,
        bytes memory data,
        uint256 eta
    ) external onlyAdmin {
        bytes32 txHash = keccak256(abi.encode(target, value, data, eta));
        queuedTransactions[txHash] = false;
        emit CancelTransaction(txHash, target, value, data, eta);
    }

    function executeTransaction(
        address target,
        uint256 value,
        bytes memory data,
        uint256 eta
    ) external payable onlyAdmin returns (bytes memory) {
        bytes32 txHash = keccak256(abi.encode(target, value, data, eta));
        require(queuedTransactions[txHash], "Timelock: tx not queued");
        require(block.timestamp >= eta, "Timelock: too early");
        require(block.timestamp <= eta + GRACE_PERIOD, "Timelock: tx stale");

        queuedTransactions[txHash] = false;

        (bool success, bytes memory returnData) = target.call{value: value}(data);
        require(success, "Timelock: tx reverted");

        emit ExecuteTransaction(txHash, target, value, data, eta);
        return returnData;
    }
}