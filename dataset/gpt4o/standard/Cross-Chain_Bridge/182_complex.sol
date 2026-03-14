// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

contract CrossChainBridge {
    struct Message {
        address sender;
        address recipient;
        uint256 amount;
        uint256 nonce;
        bytes32 dataHash;
    }

    address[] public validators;
    mapping(address => bool) public isValidator;
    mapping(bytes32 => bool) public processedMessages;
    mapping(bytes32 => bool) public emergencyPausedChains;
    uint256 public rateLimitPeriod;
    uint256 public maxMessagesPerPeriod;
    mapping(address => uint256) public lastMessageTime;
    mapping(address => uint256) public messagesInCurrentPeriod;
    uint256 public requiredConfirmations;
    address public owner;

    event MessageSent(address indexed sender, address indexed recipient, uint256 amount, uint256 nonce, bytes32 dataHash);
    event MessageConfirmed(bytes32 messageHash);
    event EmergencyPause(bytes32 chainId, bool paused);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }

    modifier onlyValidator() {
        require(isValidator[msg.sender], "Not a validator");
        _;
    }

    constructor(address[] memory _validators, uint256 _rateLimitPeriod, uint256 _maxMessagesPerPeriod, uint256 _requiredConfirmations) {
        owner = msg.sender;
        validators = _validators;
        rateLimitPeriod = _rateLimitPeriod;
        maxMessagesPerPeriod = _maxMessagesPerPeriod;
        requiredConfirmations = _requiredConfirmations;

        for (uint256 i = 0; i < _validators.length; i++) {
            isValidator[_validators[i]] = true;
        }
    }

    function sendMessage(address recipient, uint256 amount, uint256 nonce, bytes32 dataHash) external {
        require(!emergencyPausedChains[keccak256(abi.encodePacked(block.chainid))], "Bridge paused");
        require(canSendMessage(msg.sender), "Rate limit exceeded");

        bytes32 messageHash = keccak256(abi.encodePacked(msg.sender, recipient, amount, nonce, dataHash));
        require(!processedMessages[messageHash], "Message already processed");

        processedMessages[messageHash] = true;
        lastMessageTime[msg.sender] = block.timestamp;
        messagesInCurrentPeriod[msg.sender]++;

        emit MessageSent(msg.sender, recipient, amount, nonce, dataHash);
    }

    function confirmMessage(bytes32 messageHash, bytes[] memory signatures) external onlyValidator {
        require(signatures.length >= requiredConfirmations, "Not enough confirmations");

        // Verify signatures
        bytes32 ethSignedMessageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));
        address[] memory signers = new address[](signatures.length);

        for (uint256 i = 0; i < signatures.length; i++) {
            address signer = recoverSigner(ethSignedMessageHash, signatures[i]);
            require(isValidator[signer], "Invalid signature");
            signers[i] = signer;
        }

        // Check for duplicates in signers
        for (uint256 i = 0; i < signers.length; i++) {
            for (uint256 j = i + 1; j < signers.length; j++) {
                require(signers[i] != signers[j], "Duplicate signatures");
            }
        }

        emit MessageConfirmed(messageHash);
    }

    function emergencyPause(bytes32 chainId, bool paused) external onlyOwner {
        emergencyPausedChains[chainId] = paused;
        emit EmergencyPause(chainId, paused);
    }

    function canSendMessage(address sender) internal view returns (bool) {
        if (block.timestamp > lastMessageTime[sender] + rateLimitPeriod) {
            return true;
        }
        return messagesInCurrentPeriod[sender] < maxMessagesPerPeriod;
    }

    function recoverSigner(bytes32 _ethSignedMessageHash, bytes memory _signature) internal pure returns (address) {
        require(_signature.length == 65, "Invalid signature length");
        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly {
            r := mload(add(_signature, 0x20))
            s := mload(add(_signature, 0x40))
            v := byte(0, mload(add(_signature, 0x60)))
        }
        return ecrecover(_ethSignedMessageHash, v, r, s);
    }
}