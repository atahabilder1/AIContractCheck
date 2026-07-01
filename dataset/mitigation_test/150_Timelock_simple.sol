// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract Timelock is Ownable, ReentrancyGuard {
    uint256 public constant MINIMUM_DELAY = 1 days;
    uint256 public constant MAXIMUM_DELAY = 30 days;
    
    uint256 public delay;
    
    mapping(bytes32 => bool) public queuedTransactions;
    
    event TransactionQueued(
        bytes32 indexed txHash,
        address indexed target,
        uint256 value,
        string signature,
        bytes data,
        uint256 executeTime
    );
    
    event TransactionExecuted(
        bytes32 indexed txHash,
        address indexed target,
        uint256 value,
        string signature,
        bytes data,
        uint256 executeTime
    );
    
    event TransactionCancelled(bytes32 indexed txHash);
    
    event DelayChanged(uint256 oldDelay, uint256 newDelay);
    
    modifier validDelay(uint256 _delay) {
        require(_delay >= MINIMUM_DELAY, "Timelock: delay below minimum");
        require(_delay <= MAXIMUM_DELAY, "Timelock: delay above maximum");
        _;
    }
    
    modifier validTarget(address _target) {
        require(_target != address(0), "Timelock: target cannot be zero address");
        _;
    }
    
    constructor(uint256 _delay) validDelay(_delay) {
        delay = _delay;
    }
    
    function setDelay(uint256 _delay) external onlyOwner validDelay(_delay) {
        uint256 oldDelay = delay;
        delay = _delay;
        emit DelayChanged(oldDelay, _delay);
    }
    
    function queueTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data
    ) external onlyOwner validTarget(target) returns (bytes32) {
        uint256 executeTime = block.timestamp + delay;
        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, executeTime));
        
        require(!queuedTransactions[txHash], "Timelock: transaction already queued");
        
        queuedTransactions[txHash] = true;
        
        emit TransactionQueued(txHash, target, value, signature, data, executeTime);
        
        return txHash;
    }
    
    function executeTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 executeTime
    ) external payable onlyOwner nonReentrant validTarget(target) returns (bytes memory) {
        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, executeTime));
        
        require(queuedTransactions[txHash], "Timelock: transaction not queued");
        require(block.timestamp >= executeTime, "Timelock: transaction not ready");
        
        // Effects
        queuedTransactions[txHash] = false;
        
        // Interactions
        bytes memory callData;
        if (bytes(signature).length == 0) {
            callData = data;
        } else {
            callData = abi.encodePacked(bytes4(keccak256(bytes(signature))), data);
        }
        
        (bool success, bytes memory returnData) = target.call{value: value}(callData);
        require(success, "Timelock: transaction execution failed");
        
        emit TransactionExecuted(txHash, target, value, signature, data, executeTime);
        
        return returnData;
    }
    
    function cancelTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 executeTime
    ) external onlyOwner validTarget(target) {
        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, executeTime));
        
        require(queuedTransactions[txHash], "Timelock: transaction not queued");
        
        queuedTransactions[txHash] = false;
        
        emit TransactionCancelled(txHash);
    }
    
    function getTransactionHash(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 executeTime
    ) external pure returns (bytes32) {
        return keccak256(abi.encode(target, value, signature, data, executeTime));
    }
    
    receive() external payable {}
}