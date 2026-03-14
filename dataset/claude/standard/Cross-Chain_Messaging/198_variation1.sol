// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract CrossChainBatchMessenger {
    struct Message {
        address sender;
        uint256 targetChainId;
        address targetContract;
        bytes payload;
        uint256 timestamp;
    }

    struct Batch {
        uint256 id;
        uint256 targetChainId;
        Message[] messages;
        bytes32 merkleRoot;
        bool relayed;
    }

    address public owner;
    address public relayer;
    uint256 public batchCounter;
    uint256 public maxBatchSize;
    uint256 public batchTimeout;

    mapping(uint256 => Batch) public batches;
    mapping(uint256 => Message[]) public pendingMessages;
    mapping(uint256 => uint256) public pendingCounts;
    mapping(uint256 => uint256) public lastBatchTimestamp;
    mapping(bytes32 => bool) public processedBatches;
    mapping(uint256 => mapping(uint256 => bool)) public processedMessages;

    event MessageQueued(uint256 indexed targetChainId, uint256 indexed messageIndex, address sender, address targetContract);
    event BatchCreated(uint256 indexed batchId, uint256 indexed targetChainId, uint256 messageCount, bytes32 merkleRoot);
    event BatchRelayed(uint256 indexed batchId, uint256 indexed sourceChainId, uint256 messageCount);
    event MessageExecuted(uint256 indexed batchId, uint256 indexed messageIndex, address targetContract, bool success);
    event RelayerUpdated(address indexed oldRelayer, address indexed newRelayer);
    event BatchConfigUpdated(uint256 maxBatchSize, uint256 batchTimeout);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier onlyRelayer() {
        require(msg.sender == relayer, "Not relayer");
        _;
    }

    constructor(address _relayer, uint256 _maxBatchSize, uint256 _batchTimeout) {
        owner = msg.sender;
        relayer = _relayer;
        maxBatchSize = _maxBatchSize;
        batchTimeout = _batchTimeout;
    }

    function queueMessage(
        uint256 _targetChainId,
        address _targetContract,
        bytes calldata _payload
    ) external {
        require(_targetChainId != block.chainid, "Cannot message same chain");
        require(_targetContract != address(0), "Invalid target");

        uint256 index = pendingCounts[_targetChainId];
        pendingMessages[_targetChainId].push(Message({
            sender: msg.sender,
            targetChainId: _targetChainId,
            targetContract: _targetContract,
            payload: _payload,
            timestamp: block.timestamp
        }));
        pendingCounts[_targetChainId]++;

        emit MessageQueued(_targetChainId, index, msg.sender, _targetContract);

        if (pendingCounts[_targetChainId] >= maxBatchSize) {
            _createBatch(_targetChainId);
        }
    }

    function flushBatch(uint256 _targetChainId) external {
        require(pendingCounts[_targetChainId] > 0, "No pending messages");
        require(
            block.timestamp >= lastBatchTimestamp[_targetChainId] + batchTimeout,
            "Batch timeout not reached"
        );
        _createBatch(_targetChainId);
    }

    function _createBatch(uint256 _targetChainId) internal {
        uint256 count = pendingCounts[_targetChainId];
        require(count > 0, "No messages");

        uint256 batchId = batchCounter++;
        Batch storage batch = batches[batchId];
        batch.id = batchId;
        batch.targetChainId = _targetChainId;

        bytes32[] memory leaves = new bytes32[](count);
        for (uint256 i = 0; i < count; i++) {
            Message storage m = pendingMessages[_targetChainId][i];
            batch.messages.push(m);
            leaves[i] = keccak256(abi.encodePacked(m.sender, m.targetContract, m.payload, m.timestamp, i));
        }

        batch.merkleRoot = _computeMerkleRoot(leaves);
        batch.relayed = false;

        delete pendingMessages[_targetChainId];
        pendingCounts[_targetChainId] = 0;
        lastBatchTimestamp[_targetChainId] = block.timestamp;

        emit BatchCreated(batchId, _targetChainId, count, batch.merkleRoot);
    }

    function receiveBatch(
        uint256 _batchId,
        uint256 _sourceChainId,
        bytes32 _merkleRoot,
        address[] calldata _targets,
        bytes[] calldata _payloads,
        address[] calldata _senders,
        uint256[] calldata _timestamps
    ) external onlyRelayer {
        require(_targets.length == _payloads.length, "Length mismatch");
        require(_targets.length == _senders.length, "Length mismatch");
        require(_targets.length == _timestamps.length, "Length mismatch");

        bytes32 batchHash = keccak256(abi.encodePacked(_batchId, _sourceChainId, _merkleRoot));
        require(!processedBatches[batchHash], "Batch already processed");

        bytes32[] memory leaves = new bytes32[](_targets.length);
        for (uint256 i = 0; i < _targets.length; i++) {
            leaves[i] = keccak256(abi.encodePacked(_senders[i], _targets[i], _payloads[i], _timestamps[i], i));
        }
        require(_computeMerkleRoot(leaves) == _merkleRoot, "Invalid merkle root");

        processedBatches[batchHash] = true;

        for (uint256 i = 0; i < _targets.length; i++) {
            if (processedMessages[_batchId][i]) continue;
            processedMessages[_batchId][i] = true;

            bytes memory callData = abi.encodeWithSignature(
                "onCrossChainMessage(address,uint256,bytes)",
                _senders[i],
                _sourceChainId,
                _payloads[i]
            );

            (bool success,) = _targets[i].call(callData);
            emit MessageExecuted(_batchId, i, _targets[i], success);
        }

        emit BatchRelayed(_batchId, _sourceChainId, _targets.length);
    }

    function _computeMerkleRoot(bytes32[] memory leaves) internal pure returns (bytes32) {
        if (leaves.length == 0) return bytes32(0);
        if (leaves.length == 1) return leaves[0];

        uint256 n = leaves.length;
        while (n > 1) {
            uint256 next = (n + 1) / 2;
            for (uint256 i = 0; i < n / 2; i++) {
                bytes32 left = leaves[2 * i];
                bytes32 right = leaves[2 * i + 1];
                leaves[i] = left < right
                    ? keccak256(abi.encodePacked(left, right))
                    : keccak256(abi.encodePacked(right, left));
            }
            if (n % 2 == 1) {
                leaves[next - 1] = leaves[n - 1];
            }
            n = next;
        }
        return leaves[0];
    }

    function getPendingCount(uint256 _targetChainId) external view returns (uint256) {
        return pendingCounts[_targetChainId];
    }

    function getBatchMessages(uint256 _batchId) external view returns (Message[] memory) {
        return batches[_batchId].messages;
    }

    function setRelayer(address _relayer) external onlyOwner {
        require(_relayer != address(0), "Invalid relayer");
        emit RelayerUpdated(relayer, _relayer);
        relayer = _relayer;
    }

    function setBatchConfig(uint256 _maxBatchSize, uint256 _batchTimeout) external onlyOwner {
        require(_maxBatchSize > 0, "Invalid batch size");
        maxBatchSize = _maxBatchSize;
        batchTimeout = _batchTimeout;
        emit BatchConfigUpdated(_maxBatchSize, _batchTimeout);
    }
}