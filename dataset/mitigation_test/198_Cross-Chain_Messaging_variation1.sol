// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract CrossChainBatchMessaging is ReentrancyGuard, AccessControl, Pausable {
    using SafeERC20 for IERC20;

    bytes32 public constant RELAYER_ROLE = keccak256("RELAYER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    struct Message {
        address sender;
        address target;
        bytes data;
        uint256 value;
        uint256 gasLimit;
        uint256 nonce;
    }

    struct MessageBatch {
        uint256 batchId;
        uint256 sourceChainId;
        uint256 targetChainId;
        Message[] messages;
        uint256 totalValue;
        uint256 totalGasLimit;
        bytes32 merkleRoot;
        bool executed;
    }

    mapping(uint256 => MessageBatch) public batches;
    mapping(bytes32 => bool) public processedMessages;
    mapping(address => uint256) public userNonces;
    mapping(uint256 => bool) public supportedChains;
    mapping(address => bool) public authorizedSenders;

    uint256 public currentBatchId;
    uint256 public maxBatchSize = 100;
    uint256 public minGasLimit = 21000;
    uint256 public maxGasLimit = 5000000;
    uint256 public baseFee = 0.001 ether;
    
    IERC20 public feeToken;
    address public feeCollector;

    event MessageQueued(
        address indexed sender,
        address indexed target,
        uint256 indexed nonce,
        bytes data,
        uint256 value,
        uint256 gasLimit
    );

    event BatchCreated(
        uint256 indexed batchId,
        uint256 indexed sourceChainId,
        uint256 indexed targetChainId,
        uint256 messageCount,
        bytes32 merkleRoot
    );

    event BatchExecuted(
        uint256 indexed batchId,
        uint256 successCount,
        uint256 failureCount
    );

    event MessageExecuted(
        uint256 indexed batchId,
        uint256 indexed messageIndex,
        bool success,
        bytes returnData
    );

    modifier onlyRelayer() {
        require(hasRole(RELAYER_ROLE, msg.sender), "Not authorized relayer");
        _;
    }

    modifier onlyAdmin() {
        require(hasRole(ADMIN_ROLE, msg.sender), "Not authorized admin");
        _;
    }

    modifier onlyAuthorizedSender() {
        require(authorizedSenders[msg.sender] || hasRole(ADMIN_ROLE, msg.sender), "Not authorized sender");
        _;
    }

    modifier validChain(uint256 chainId) {
        require(supportedChains[chainId], "Unsupported chain");
        _;
    }

    modifier validGasLimit(uint256 gasLimit) {
        require(gasLimit >= minGasLimit && gasLimit <= maxGasLimit, "Invalid gas limit");
        _;
    }

    constructor(
        address _feeToken,
        address _feeCollector,
        address _admin
    ) {
        require(_feeToken != address(0), "Zero fee token address");
        require(_feeCollector != address(0), "Zero fee collector address");
        require(_admin != address(0), "Zero admin address");

        feeToken = IERC20(_feeToken);
        feeCollector = _feeCollector;

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(ADMIN_ROLE, _admin);
        _grantRole(RELAYER_ROLE, _admin);

        supportedChains[block.chainid] = true;
        currentBatchId = 1;
    }

    function queueMessage(
        address target,
        bytes calldata data,
        uint256 value,
        uint256 gasLimit,
        uint256 targetChainId
    ) 
        external 
        payable 
        nonReentrant 
        whenNotPaused 
        onlyAuthorizedSender
        validChain(targetChainId)
        validGasLimit(gasLimit)
    {
        require(target != address(0), "Zero target address");
        require(msg.value >= baseFee + value, "Insufficient fee");

        uint256 nonce = userNonces[msg.sender]++;
        
        emit MessageQueued(
            msg.sender,
            target,
            nonce,
            data,
            value,
            gasLimit
        );

        // Collect fee
        if (address(feeToken) != address(0)) {
            uint256 tokenFee = calculateTokenFee(gasLimit);
            feeToken.safeTransferFrom(msg.sender, feeCollector, tokenFee);
        }
    }

    function createBatch(
        uint256 sourceChainId,
        uint256 targetChainId,
        Message[] calldata messages,
        bytes32 merkleRoot
    ) 
        external 
        onlyRelayer 
        nonReentrant 
        whenNotPaused
        validChain(sourceChainId)
        validChain(targetChainId)
    {
        require(messages.length > 0 && messages.length <= maxBatchSize, "Invalid batch size");
        require(merkleRoot != bytes32(0), "Invalid merkle root");

        uint256 batchId = currentBatchId++;
        MessageBatch storage batch = batches[batchId];
        
        batch.batchId = batchId;
        batch.sourceChainId = sourceChainId;
        batch.targetChainId = targetChainId;
        batch.merkleRoot = merkleRoot;
        batch.executed = false;

        uint256 totalValue = 0;
        uint256 totalGasLimit = 0;

        for (uint256 i = 0; i < messages.length; i++) {
            Message memory message = messages[i];
            
            require(message.sender != address(0), "Zero sender address");
            require(message.target != address(0), "Zero target address");
            require(message.gasLimit >= minGasLimit && message.gasLimit <= maxGasLimit, "Invalid gas limit");

            batch.messages.push(message);
            totalValue += message.value;
            totalGasLimit += message.gasLimit;
        }

        batch.totalValue = totalValue;
        batch.totalGasLimit = totalGasLimit;

        emit BatchCreated(batchId, sourceChainId, targetChainId, messages.length, merkleRoot);
    }

    function executeBatch(
        uint256 batchId,
        bytes32[] calldata merkleProof
    ) 
        external 
        onlyRelayer 
        nonReentrant 
        whenNotPaused 
    {
        MessageBatch storage batch = batches[batchId];
        require(batch.batchId != 0, "Batch does not exist");
        require(!batch.executed, "Batch already executed");
        require(batch.targetChainId == block.chainid, "Wrong target chain");

        // Verify merkle proof if required
        if (merkleProof.length > 0) {
            require(verifyMerkleProof(batchId, merkleProof), "Invalid merkle proof");
        }

        batch.executed = true;

        uint256 successCount = 0;
        uint256 failureCount = 0;

        for (uint256 i = 0; i < batch.messages.length; i++) {
            Message memory message = batch.messages[i];
            bytes32 messageHash = keccak256(
                abi.encodePacked(
                    batchId,
                    i,
                    message.sender,
                    message.target,
                    message.data,
                    message.value,
                    message.nonce
                )
            );

            if (processedMessages[messageHash]) {
                failureCount++;
                emit MessageExecuted(batchId, i, false, "Already processed");
                continue;
            }

            processedMessages[messageHash] = true;

            (bool success, bytes memory returnData) = message.target.call{
                value: message.value,
                gas: message.gasLimit
            }(message.data);

            if (success) {
                successCount++;
            } else {
                failureCount++;
            }

            emit MessageExecuted(batchId, i, success, returnData);
        }

        emit BatchExecuted(batchId, successCount, failureCount);
    }

    function verifyMerkleProof(
        uint256 batchId,
        bytes32[] calldata proof
    ) internal view returns (bool) {
        MessageBatch storage batch = batches[batchId];
        bytes32 computedHash = keccak256(abi.encode(batch.messages));
        
        for (uint256 i = 0; i < proof.length; i++) {
            bytes32 proofElement = proof[i];
            if (computedHash <= proofElement) {
                computedHash = keccak256(abi.encodePacked(computedHash, proofElement));
            } else {
                computedHash = keccak256(abi.encodePacked(proofElement, computedHash));
            }
        }

        return computedHash == batch.merkleRoot;
    }

    function calculateTokenFee(uint256 gasLimit) public pure returns (uint256) {
        return (gasLimit * 1e12) / 1e18; // Simple gas-based fee calculation
    }

    function addSupportedChain(uint256 chainId) external onlyAdmin {
        require(chainId != 0, "Invalid chain ID");
        supportedChains[chainId] = true;
    }

    function removeSupportedChain(uint256 chainId) external onlyAdmin {
        require(chainId != block.chainid, "Cannot remove current chain");
        supportedChains[chainId] = false;
    }

    function authorizeSender(address sender) external onlyAdmin {
        require(sender != address(0), "Zero sender address");
        authorizedSenders[sender] = true;
    }

    function unauthorizeSender(address sender) external onlyAdmin {
        authorizedSenders[sender] = false;
    }

    function updateMaxBatchSize(uint256 newMaxBatchSize) external onlyAdmin {
        require(newMaxBatchSize > 0 && newMaxBatchSize <= 1000, "Invalid batch size");
        maxBatchSize = newMaxBatchSize;
    }

    function updateGasLimits(uint256 newMinGasLimit, uint256 newMaxGasLimit) external onlyAdmin {
        require(newMinGasLimit > 0 && newMinGasLimit < newMaxGasLimit, "Invalid gas limits");
        minGasLimit = newMinGasLimit;
        maxGasLimit = newMaxGasLimit;
    }

    function updateBaseFee(uint256 newBaseFee) external onlyAdmin {
        baseFee = newBaseFee;
    }

    function updateFeeCollector(address newFeeCollector) external onlyAdmin {
        require(newFeeCollector != address(0), "Zero fee collector address");
        feeCollector = newFeeCollector;
    }

    function pause() external onlyAdmin {
        _pause();
    }

    function unpause() external onlyAdmin {
        _unpause();
    }

    function emergencyWithdraw(address token, uint256 amount) external onlyAdmin {
        if (token == address(0)) {
            require(address(this).balance >= amount, "Insufficient ETH balance");
            payable(feeCollector).transfer(amount);
        } else {
            IERC20(token).safeTransfer(feeCollector, amount);
        }
    }

    function getBatch(uint256 batchId) external view returns (MessageBatch memory) {
        return batches[batchId];
    }

    function getBatchMessages(uint256 batchId) external view returns (Message[] memory) {
        return batches[batchId].messages;
    }

    function isMessageProcessed(bytes32 messageHash) external view returns (bool) {
        return processedMessages[messageHash];
    }

    receive() external payable {}
}