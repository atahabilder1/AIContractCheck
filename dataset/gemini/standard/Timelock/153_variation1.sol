// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract Timelock is Ownable, ReentrancyGuard {
    event Deposit(address indexed user, uint256 amount);
    event Withdrawal(address indexed user, uint256 amount);
    event Execute(address indexed target, bytes data);
    event FastTrackExecute(address indexed target, bytes data);
    event GuardianAdded(address indexed guardian);
    event GuardianRemoved(address indexed guardian);
    event QuorumSet(uint256 newQuorum);
    event VotingPeriodSet(uint256 newVotingPeriod);

    mapping(address => bool) public isGuardian;
    address[] public guardians;
    uint256 public constant MAX_GUARDIANS = 10; // Arbitrary limit
    uint256 public quorum; // Number of guardians required to approve a transaction
    uint256 public votingPeriod; // Duration in seconds for voting

    struct Transaction {
        address target;
        bytes data;
        uint256 eta; // Estimated time of arrival (execution timestamp)
        bool executed;
        mapping(address => bool) hasVoted;
        uint256 voteCount;
    }

    mapping(bytes32 => Transaction) public transactions;

    constructor(uint256 _initialQuorum, uint256 _initialVotingPeriod) {
        require(_initialQuorum > 0 && _initialQuorum <= MAX_GUARDIANS, "Invalid initial quorum");
        require(_initialVotingPeriod > 0, "Voting period must be positive");
        quorum = _initialQuorum;
        votingPeriod = _initialVotingPeriod;
    }

    modifier onlyGuardian() {
        require(isGuardian[msg.sender], "Timelock: caller is not a guardian");
        _;
    }

    modifier onlyNotGuardian() {
        require(!isGuardian[msg.sender], "Timelock: caller is a guardian");
        _;
    }

    function addGuardian(address _guardian) public onlyOwner {
        require(_guardian != address(0), "Timelock: invalid guardian address");
        require(guardians.length < MAX_GUARDIANS, "Timelock: maximum guardians reached");
        require(!isGuardian[_guardian], "Timelock: guardian already added");

        isGuardian[_guardian] = true;
        guardians.push(_guardian);
        emit GuardianAdded(_guardian);
    }

    function removeGuardian(address _guardian) public onlyOwner {
        require(isGuardian[_guardian], "Timelock: guardian not found");

        isGuardian[_guardian] = false;
        for (uint256 i = 0; i < guardians.length; i++) {
            if (guardians[i] == _guardian) {
                guardians[i] = guardians[guardians.length - 1];
                guardians.pop();
                break;
            }
        }
        emit GuardianRemoved(_guardian);
    }

    function setQuorum(uint256 _newQuorum) public onlyOwner {
        require(_newQuorum > 0 && _newQuorum <= guardians.length, "Timelock: invalid quorum");
        quorum = _newQuorum;
        emit QuorumSet(_newQuorum);
    }

    function setVotingPeriod(uint256 _newVotingPeriod) public onlyOwner {
        require(_newVotingPeriod > 0, "Timelock: voting period must be positive");
        votingPeriod = _newVotingPeriod;
        emit VotingPeriodSet(_newVotingPeriod);
    }

    function queueTransaction(address _target, bytes calldata _data, uint256 _delay) public onlyGuardian {
        bytes32 txHash = keccak256(abi.encodePacked(_target, _data, block.timestamp + _delay));
        require(transactions[txHash].target == address(0), "Timelock: transaction already queued");

        transactions[txHash] = Transaction({
            target: _target,
            data: _data,
            eta: block.timestamp + _delay,
            executed: false,
            voteCount: 0
        });

        // Reset votes for this transaction
        // This is a simplification. A more robust implementation might track voted addresses per transaction.
        // For now, we assume guardians can vote only once per queued transaction.
        // The mapping `hasVoted` is within the Transaction struct, so it's specific to each txHash.
    }

    function cancelTransaction(address _target, bytes calldata _data, uint256 _delay) public onlyGuardian {
        bytes32 txHash = keccak256(abi.encodePacked(_target, _data, block.timestamp + _delay));
        require(transactions[txHash].target != address(0), "Timelock: transaction not found");
        require(!transactions[txHash].executed, "Timelock: transaction already executed");
        // Optionally, add a check to see if the caller is the one who queued it or if a certain threshold of guardians agree to cancel.
        // For simplicity here, any guardian can cancel.

        delete transactions[txHash];
    }

    function vote(bytes32 _txHash) public onlyGuardian {
        Transaction storage tx = transactions[_txHash];
        require(tx.target != address(0), "Timelock: transaction not found");
        require(!tx.executed, "Timelock: transaction already executed");
        require(block.timestamp < tx.eta, "Timelock: voting period has ended");
        require(!tx.hasVoted[msg.sender], "Timelock: already voted");

        tx.hasVoted[msg.sender] = true;
        tx.voteCount++;

        if (tx.voteCount >= quorum) {
            // If quorum is reached, the transaction can be executed immediately if eta has passed or will pass soon.
            // The actual execution will happen in `executeTransaction`.
        }
    }

    function executeTransaction(address _target, bytes calldata _data, uint256 _delay) public nonReentrant {
        bytes32 txHash = keccak256(abi.encodePacked(_target, _data, block.timestamp + _delay));
        Transaction storage tx = transactions[txHash];

        require(tx.target != address(0), "Timelock: transaction not found");
        require(!tx.executed, "Timelock: transaction already executed");
        require(block.timestamp >= tx.eta, "Timelock: transaction is not yet ready");

        // Check if quorum was met for this transaction.
        // This ensures that even if the ETA is reached, the transaction must have been approved.
        require(tx.voteCount >= quorum, "Timelock: quorum not met");

        tx.executed = true;

        (bool success, ) = _target.call{value: 0}(_data);
        require(success, "Timelock: transaction execution failed");

        emit Execute(_target, _data);
    }

    function fastTrackExecute(address _target, bytes calldata _data, uint256 _delay) public nonReentrant {
        bytes32 txHash = keccak256(abi.encodePacked(_target, _data, block.timestamp + _delay));
        Transaction storage tx = transactions[txHash];

        require(tx.target != address(0), "Timelock: transaction not found");
        require(!tx.executed, "Timelock: transaction already executed");
        require(block.timestamp >= tx.eta, "Timelock: transaction is not yet ready");

        // Supermajority check for fast-track
        // For example, 2/3 of guardians
        uint256 superMajorityThreshold = (guardians.length * 2) / 3;
        if (guardians.length > 0 && superMajorityThreshold == 0) {
            superMajorityThreshold = 1; // Ensure at least 1 for small guardian counts
        }

        require(tx.voteCount >= superMajorityThreshold, "Timelock: supermajority not met for fast-track");

        tx.executed = true;

        (bool success, ) = _target.call{value: 0}(_data);
        require(success, "Timelock: fast-track transaction execution failed");

        emit FastTrackExecute(_target, _data);
    }

    function deposit() public payable {
        emit Deposit(msg.sender, msg.value);
    }

    function withdraw(uint256 _amount) public onlyGuardian {
        require(address(this).balance >= _amount, "Timelock: insufficient balance");
        payable(msg.sender).transfer(_amount);
        emit Withdrawal(msg.sender, _amount);
    }

    function getTransaction(bytes32 _txHash) public view returns (address target, bytes memory data, uint256 eta, bool executed, uint256 voteCount) {
        Transaction storage tx = transactions[_txHash];
        return (tx.target, tx.data, tx.eta, tx.executed, tx.voteCount);
    }

    function getGuardians() public view returns (address[] memory) {
        return guardians;
    }

    function getQuorum() public view returns (uint256) {
        return quorum;
    }

    function getVotingPeriod() public view returns (uint256) {
        return votingPeriod;
    }
}