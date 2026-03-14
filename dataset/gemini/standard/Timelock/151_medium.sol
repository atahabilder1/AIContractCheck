// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/arrays/Arrays.sol";

contract Timelock is Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;
    using Arrays for uint256[];

    event Log(address indexed target, bytes data, uint256 value, uint256 delay, uint256 eta);
    event Cancel(address indexed target, bytes data, uint256 value, uint256 delay);
    event Execute(address indexed target, bytes data, uint256 value, uint256 eta);
    event QueueTransaction(address indexed target, bytes data, uint256 value, uint256 delay, uint256 eta);

    struct Transaction {
        address target;
        uint256 value;
        bytes data;
        uint256 eta;
        uint256 delay;
    }

    mapping(bytes32 => Transaction) public transactions;
    EnumerableSet.AddressSet private queuedTransactions; // Stores keccak256 hashes of transactions

    uint256 public constant MINIMUM_DELAY = 1 days;
    uint256 public constant MAXIMUM_DELAY = 30 days;

    uint256 public constant MINIMUM_GRACE_PERIOD = 1 days;
    uint256 public constant MAXIMUM_GRACE_PERIOD = 30 days;

    uint256 public delay;
    uint256 public gracePeriod;

    constructor(address initialAdmin, uint256 _delay, uint256 _gracePeriod) Ownable(initialAdmin) {
        require(_delay >= MINIMUM_DELAY && _delay <= MAXIMUM_DELAY, "Delay out of bounds");
        require(_gracePeriod >= MINIMUM_GRACE_PERIOD && _gracePeriod <= MAXIMUM_GRACE_PERIOD, "Grace period out of bounds");
        delay = _delay;
        gracePeriod = _gracePeriod;
    }

    function setDelay(uint256 _newDelay) public onlyOwner {
        require(_newDelay >= MINIMUM_DELAY && _newDelay <= MAXIMUM_DELAY, "Delay out of bounds");
        delay = _newDelay;
    }

    function setGracePeriod(uint256 _newGracePeriod) public onlyOwner {
        require(_newGracePeriod >= MINIMUM_GRACE_PERIOD && _newGracePeriod <= MAXIMUM_GRACE_PERIOD, "Grace period out of bounds");
        gracePeriod = _newGracePeriod;
    }

    function queueTransaction(address target, uint256 value, bytes memory data, uint256 _delay) public onlyOwner {
        uint256 eta = block.timestamp + _delay;
        bytes32 txHash = keccak256(abi.encodePacked(target, value, data, eta));
        require(transactions[txHash].target == address(0), "Transaction already queued");
        require(_delay >= delay, "Delay must be at least the minimum delay");

        transactions[txHash] = Transaction({
            target: target,
            value: value,
            data: data,
            eta: eta,
            delay: _delay
        });

        queuedTransactions.add(bytesToAddress(txHash)); // Store hash in a set of addresses for easier iteration

        emit QueueTransaction(target, data, value, _delay, eta);
    }

    function executeTransaction(address target, uint256 value, bytes memory data, uint256 eta, uint256 txDelay) public payable {
        bytes32 txHash = keccak256(abi.encodePacked(target, value, data, eta));
        require(transactions[txHash].target != address(0), "Transaction not queued");
        require(block.timestamp >= eta, "Transaction not yet ready");
        require(block.timestamp <= eta + gracePeriod, "Transaction expired");
        require(txDelay >= transactions[txHash].delay, "Incorrect delay provided");

        // Remove from queued transactions
        queuedTransactions.remove(bytesToAddress(txHash));
        delete transactions[txHash];

        (bool success, ) = target.call{value: value}(data);
        require(success, "Transaction failed");

        emit Execute(target, data, value, eta);
    }

    function cancelTransaction(address target, uint256 value, bytes memory data, uint256 eta) public onlyOwner {
        bytes32 txHash = keccak256(abi.encodePacked(target, value, data, eta));
        require(transactions[txHash].target != address(0), "Transaction not queued");
        require(block.timestamp < eta, "Transaction already passed its eta");

        // Remove from queued transactions
        queuedTransactions.remove(bytesToAddress(txHash));
        delete transactions[txHash];

        emit Cancel(target, data, value, transactions[txHash].delay);
    }

    function executeBatchTransactions(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory datas,
        uint256[] memory etas,
        uint256[] memory delays
    ) public payable {
        require(targets.length == values.length && targets.length == datas.length && targets.length == etas.length && targets.length == delays.length, "Mismatched array lengths");

        for (uint256 i = 0; i < targets.length; i++) {
            address target = targets[i];
            uint256 value = values[i];
            bytes memory data = datas[i];
            uint256 eta = etas[i];
            uint256 txDelay = delays[i];

            bytes32 txHash = keccak256(abi.encodePacked(target, value, data, eta));
            require(transactions[txHash].target != address(0), "Transaction not queued");
            require(block.timestamp >= eta, "Transaction not yet ready");
            require(block.timestamp <= eta + gracePeriod, "Transaction expired");
            require(txDelay >= transactions[txHash].delay, "Incorrect delay provided");

            // Remove from queued transactions
            queuedTransactions.remove(bytesToAddress(txHash));
            delete transactions[txHash];

            (bool success, ) = target.call{value: value}(data);
            require(success, "Transaction failed");

            emit Execute(target, data, value, eta);
        }
    }

    function getQueuedTransactions() public view returns (address[] memory) {
        address[] memory _queuedTransactions = new address[](queuedTransactions.length());
        for (uint256 i = 0; i < queuedTransactions.length(); i++) {
            _queuedTransactions[i] = queuedTransactions.at(i);
        }
        return _queuedTransactions;
    }

    // Helper function to convert bytes32 hash to address for EnumerableSet
    function bytesToAddress(bytes32 _bytes32) internal pure returns (address) {
        return address(uint160(uint256(_bytes32)));
    }
}