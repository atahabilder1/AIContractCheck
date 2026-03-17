// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Timelock {
    address payable public executor;
    uint public delay;

    constructor(address _executor, uint _delay) {
        executor = payable(_executor);
        delay = _delay;
    }

    struct QueuedTransaction {
        address target;
        bytes data;
        uint eta;
    }

    mapping(bytes32 => QueuedTransaction) public queuedTransactions;

    function queueTransaction(address target, bytes memory data) external {
        bytes32 txHash = keccak256(abi.encode(target, data));
        require(!queuedTransactions[txHash].valid, "Transaction already queued.");
        queuedTransactions[txHash] = QueuedTransaction({
            target: target,
            data: data,
            eta: block.timestamp + delay
        });
    }

    function executeTransaction(address target, bytes memory data) external {
        bytes32 txHash = keccak256(abi.encode(target, data));
        QueuedTransaction storage qtx = queuedTransactions[txHash];
        require(qtx.valid && qtx.eta <= block.timestamp, "Transaction cannot be executed.");
        (bool success, ) = target.call{value: address(this).balance}(data);
        require(success, "Execution failed.");
    }
}