// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract BridgeRelayer {
    struct Message {
        uint256 sourceChainId;
        uint256 destChainId;
        address sender;
        address recipient;
        bytes data;
        uint256 nonce;
        uint256 fee;
    }

    struct RelayerInfo {
        bool isActive;
        uint256 stake;
        uint256 feesEarned;
        uint256 addedAt;
    }

    address public owner;
    uint256 public requiredSignatures;
    uint256 public relayerCount;
    uint256 public minStake;
    uint256 public protocolFeeRate; // basis points (e.g., 100 = 1%)
    uint256 public accumulatedProtocolFees;
    uint256 public rotationInterval;
    uint256 public lastRotationTime;
    uint256 public currentEpoch;

    mapping(address => RelayerInfo) public relayers;
    address[] public relayerList;
    mapping(bytes32 => bool) public processedMessages;
    mapping(bytes32 => mapping(address => bool)) public messageConfirmations;
    mapping(bytes32 => uint256) public confirmationCount;
    mapping(uint256 => address[]) public epochActiveRelayers;

    event MessageRelayed(
        bytes32 indexed messageHash,
        uint256 sourceChainId,
        address indexed sender,
        address indexed recipient,
        uint256 nonce
    );
    event RelayerAdded(address indexed relayer, uint256 stake);
    event RelayerRemoved(address indexed relayer);
    event RelayerRotated(uint256 indexed epoch, address[] activeRelayers);
    event SignatureSubmitted(bytes32 indexed messageHash, address indexed relayer);
    event FeesCollected(address indexed relayer, uint256 amount);
    event ProtocolFeesWithdrawn(address indexed to, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier onlyActiveRelayer() {
        require(relayers[msg.sender].isActive, "Not active relayer");
        _;
    }

    constructor(
        uint256 _requiredSignatures,
        uint256 _minStake,
        uint256 _protocolFeeRate,
        uint256 _rotationInterval
    ) {
        owner = msg.sender;
        requiredSignatures = _requiredSignatures;
        minStake = _minStake;
        protocolFeeRate = _protocolFeeRate;
        rotationInterval = _rotationInterval;
        lastRotationTime = block.timestamp;
        currentEpoch = 1;
    }

    function addRelayer(address _relayer) external payable onlyOwner {
        require(!relayers[_relayer].isActive, "Already a relayer");
        require(msg.value >= minStake, "Insufficient stake");

        relayers[_relayer] = RelayerInfo({
            isActive: true,
            stake: msg.value,
            feesEarned: 0,
            addedAt: block.timestamp
        });
        relayerList.push(_relayer);
        relayerCount++;

        emit RelayerAdded(_relayer, msg.value);
    }

    function removeRelayer(address _relayer) external onlyOwner {
        require(relayers[_relayer].isActive, "Not a relayer");

        uint256 stake = relayers[_relayer].stake;
        relayers[_relayer].isActive = false;
        relayers[_relayer].stake = 0;
        relayerCount--;

        for (uint256 i = 0; i < relayerList.length; i++) {
            if (relayerList[i] == _relayer) {
                relayerList[i] = relayerList[relayerList.length - 1];
                relayerList.pop();
                break;
            }
        }

        (bool sent, ) = _relayer.call{value: stake}("");
        require(sent, "Stake return failed");

        emit RelayerRemoved(_relayer);
    }

    function rotateRelayers() external {
        require(
            block.timestamp >= lastRotationTime + rotationInterval,
            "Too early for rotation"
        );
        require(relayerCount >= requiredSignatures, "Not enough relayers");

        currentEpoch++;
        lastRotationTime = block.timestamp;

        delete epochActiveRelayers[currentEpoch];

        uint256 seed = uint256(
            keccak256(
                abi.encodePacked(
                    block.timestamp,
                    block.prevrandao,
                    currentEpoch
                )
            )
        );

        address[] memory candidates = new address[](relayerList.length);
        uint256 candidateCount = relayerList.length;
        for (uint256 i = 0; i < relayerList.length; i++) {
            candidates[i] = relayerList[i];
        }

        uint256 selectCount = candidateCount < requiredSignatures + 2
            ? candidateCount
            : requiredSignatures + 2;

        for (uint256 i = 0; i < selectCount; i++) {
            uint256 idx = (uint256(keccak256(abi.encodePacked(seed, i)))) %
                (candidateCount - i);
            epochActiveRelayers[currentEpoch].push(candidates[idx]);
            candidates[idx] = candidates[candidateCount - 1 - i];
        }

        emit RelayerRotated(currentEpoch, epochActiveRelayers[currentEpoch]);
    }

    function getMessageHash(
        Message calldata _message
    ) public pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    _message.sourceChainId,
                    _message.destChainId,
                    _message.sender,
                    _message.recipient,
                    _message.data,
                    _message.nonce,
                    _message.fee
                )
            );
    }

    function getEthSignedMessageHash(
        bytes32 _messageHash
    ) public pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    "\x19Ethereum Signed Message:\n32",
                    _messageHash
                )
            );
    }

    function submitSignature(
        Message calldata _message,
        bytes calldata _signature
    ) external onlyActiveRelayer {
        bytes32 messageHash = getMessageHash(_message);
        require(!processedMessages[messageHash], "Message already processed");
        require(
            !messageConfirmations[messageHash][msg.sender],
            "Already confirmed"
        );

        bytes32 ethSignedHash = getEthSignedMessageHash(messageHash);
        address signer = recoverSigner(ethSignedHash, _signature);
        require(signer == msg.sender, "Invalid signature");

        messageConfirmations[messageHash][msg.sender] = true;
        confirmationCount[messageHash]++;

        emit SignatureSubmitted(messageHash, msg.sender);

        if (confirmationCount[messageHash] >= requiredSignatures) {
            _executeMessage(_message, messageHash);
        }
    }

    function _executeMessage(
        Message calldata _message,
        bytes32 _messageHash
    ) internal {
        require(!processedMessages[_messageHash], "Already executed");
        require(
            _message.destChainId == block.chainid,
            "Wrong destination chain"
        );

        processedMessages[_messageHash] = true;

        uint256 protocolFee = (_message.fee * protocolFeeRate) / 10000;
        uint256 relayerFee = _message.fee - protocolFee;
        accumulatedProtocolFees += protocolFee;

        uint256 feePerRelayer = relayerFee / requiredSignatures;
        for (uint256 i = 0; i < relayerList.length; i++) {
            if (messageConfirmations[_messageHash][relayerList[i]]) {
                relayers[relayerList[i]].feesEarned += feePerRelayer;
            }
        }

        if (_message.data.length > 0) {
            (bool success, ) = _message.recipient.call{value: 0}(
                _message.data
            );
            require(success, "Message execution failed");
        }

        emit MessageRelayed(
            _messageHash,
            _message.sourceChainId,
            _message.sender,
            _message.recipient,
            _message.nonce
        );
    }

    function collectFees() external onlyActiveRelayer {
        uint256 fees = relayers[msg.sender].feesEarned;
        require(fees > 0, "No fees to collect");

        relayers[msg.sender].feesEarned = 0;

        (bool sent, ) = msg.sender.call{value: fees}("");
        require(sent, "Fee transfer failed");

        emit FeesCollected(msg.sender, fees);
    }

    function withdrawProtocolFees(address _to) external onlyOwner {
        uint256 fees = accumulatedProtocolFees;
        require(fees > 0, "No protocol fees");

        accumulatedProtocolFees = 0;

        (bool sent, ) = _to.call{value: fees}("");
        require(sent, "Transfer failed");

        emit ProtocolFeesWithdrawn(_to, fees);
    }

    function recoverSigner(
        bytes32 _ethSignedMessageHash,
        bytes calldata _signature
    ) public pure returns (address) {
        require(_signature.length == 65, "Invalid signature length");

        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
            r := calldataload(_signature.offset)
            s := calldataload(add(_signature.offset, 32))
            v := byte(0, calldataload(add(_signature.offset, 64)))
        }

        if (v < 27) {
            v += 27;
        }

        require(v == 27 || v == 28, "Invalid signature v value");

        return ecrecover(_ethSignedMessageHash, v, r, s);
    }

    function isMessageProcessed(
        bytes32 _messageHash
    ) external view returns (bool) {
        return processedMessages[_messageHash];
    }

    function getEpochRelayers(
        uint256 _epoch
    ) external view returns (address[] memory) {
        return epochActiveRelayers[_epoch];
    }

    function getRelayerList() external view returns (address[] memory) {
        return relayerList;
    }

    function updateRequiredSignatures(uint256 _required) external onlyOwner {
        require(_required > 0, "Must require at least 1");
        require(_required <= relayerCount, "Exceeds relayer count");
        requiredSignatures = _required;
    }

    function updateMinStake(uint256 _minStake) external onlyOwner {
        minStake = _minStake;
    }

    function updateProtocolFeeRate(uint256 _rate) external onlyOwner {
        require(_rate <= 1000, "Fee too high");
        protocolFeeRate = _rate;
    }

    receive() external payable {}
}