// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract Timelock {
    uint256 public baseDelay; // Base delay in seconds
    uint256 public delayPerEth; // Additional delay per 1 ETH in seconds

    address public admin;
    mapping(bytes32 => uint256) public transactionTimelocks;

    event TransactionScheduled(bytes32 indexed txId, uint256 eta);
    event TransactionExecuted(bytes32 indexed txId);
    event TransactionCancelled(bytes32 indexed txId);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Not authorized");
        _;
    }

    constructor(uint256 _baseDelay, uint256 _delayPerEth, address _admin) {
        baseDelay = _baseDelay;
        delayPerEth = _delayPerEth;
        admin = _admin;
    }

    function scheduleTransaction(
        bytes32 txId,
        uint256 ethValue
    ) external payable onlyAdmin {
        require(msg.value >= ethValue, "Insufficient ETH sent");
        uint256 eta = block.timestamp + calculateDelay(ethValue);
        transactionTimelocks[txId] = eta;
        emit TransactionScheduled(txId, eta);
    }

    function executeTransaction(bytes32 txId) external onlyAdmin {
        require(block.timestamp >= transactionTimelocks[txId], "Transaction not yet ready");
        delete transactionTimelocks[txId];
        emit TransactionExecuted(txId);
    }

    function cancelTransaction(bytes32 txId) external onlyAdmin {
        require(transactionTimelocks[txId] != 0, "Transaction not scheduled");
        delete transactionTimelocks[txId];
        emit TransactionCancelled(txId);
    }

    function calculateDelay(uint256 ethValue) internal view returns (uint256) {
        return baseDelay + (ethValue * delayPerEth);
    }
}