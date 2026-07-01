// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract CrossChainBridge is ReentrancyGuard, Pausable, AccessControl {
    using SafeERC20 for IERC20;
    using ECDSA for bytes32;

    bytes32 public constant VALIDATOR_ROLE = keccak256("VALIDATOR_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    struct BridgeMessage {
        uint256 nonce;
        uint256 sourceChainId;
        uint256 targetChainId;
        address token;
        address sender;
        address recipient;
        uint256 amount;
        bytes32 merkleRoot;
        uint256 blockNumber;
    }

    struct RateLimit {
        uint256 amount;
        uint256 windowStart;
        uint256 windowDuration;
        uint256 maxAmount;
    }

    mapping(uint256 => bool) public processedNonces;
    mapping(bytes32 => bool) public processedMessages;
    mapping(address => bool) public supportedTokens;
    mapping(uint256 => bool) public supportedChains;
    mapping(address => RateLimit) public rateLimits;
    mapping(bytes32 => uint256) public validatorVotes;
    mapping(bytes32 => mapping(address => bool)) public hasVoted;

    uint256 public nonce;
    uint256 public requiredValidators;
    uint256 public totalValidators;
    uint256 public constant RATE_LIMIT_WINDOW = 1 hours;
    uint256 public defaultMaxAmount = 1000000 * 10**18; // 1M tokens

    event MessageSent(
        uint256 indexed nonce,
        uint256 indexed targetChainId,
        address indexed token,
        address sender,
        address recipient,
        uint256 amount,
        bytes32 merkleRoot
    );

    event MessageProcessed(
        uint256 indexed nonce,
        uint256 indexed sourceChainId,
        address indexed token,
        address recipient,
        uint256 amount
    );

    event ValidatorAdded(address indexed validator);
    event ValidatorRemoved(address indexed validator);
    event TokenSupported(address indexed token);
    event ChainSupported(uint256 indexed chainId);

    modifier onlyValidator() {
        require(hasRole(VALIDATOR_ROLE, msg.sender), "Not a validator");
        _;
    }

    modifier onlyAdmin() {
        require(hasRole(ADMIN_ROLE, msg.sender), "Not an admin");
        _;
    }

    modifier validAddress(address _addr) {
        require(_addr != address(0), "Zero address");
        _;
    }

    modifier supportedToken(address _token) {
        require(_token != address(0), "Zero address");
        require(supportedTokens[_token], "Token not supported");
        _;
    }

    modifier supportedChain(uint256 _chainId) {
        require(_chainId != 0, "Invalid chain ID");
        require(supportedChains[_chainId], "Chain not supported");
        _;
    }

    constructor(
        address[] memory _validators,
        uint256 _requiredValidators
    ) {
        require(_validators.length > 0, "No validators provided");
        require(_requiredValidators > 0 && _requiredValidators <= _validators.length, "Invalid required validators");

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);

        for (uint256 i = 0; i < _validators.length; i++) {
            require(_validators[i] != address(0), "Zero validator address");
            _grantRole(VALIDATOR_ROLE, _validators[i]);
            totalValidators++;
        }

        requiredValidators = _requiredValidators;
        nonce = 1;
    }

    function sendMessage(
        uint256 _targetChainId,
        address _token,
        address _recipient,
        uint256 _amount,
        bytes32[] calldata _merkleProof,
        bytes32 _merkleRoot
    ) 
        external 
        nonReentrant 
        whenNotPaused 
        supportedChain(_targetChainId)
        supportedToken(_token)
        validAddress(_recipient)
    {
        require(_amount > 0, "Amount must be positive");
        require(_targetChainId != block.chainid, "Cannot bridge to same chain");
        
        // Verify merkle proof
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender, _recipient, _amount, _targetChainId));
        require(MerkleProof.verify(_merkleProof, _merkleRoot, leaf), "Invalid merkle proof");

        // Check rate limits
        _checkRateLimit(_token, _amount);

        // Transfer tokens to bridge
        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);

        uint256 currentNonce = nonce++;
        
        emit MessageSent(
            currentNonce,
            _targetChainId,
            _token,
            msg.sender,
            _recipient,
            _amount,
            _merkleRoot
        );
    }

    function processMessage(
        BridgeMessage calldata _message,
        bytes[] calldata _signatures,
        bytes32[] calldata _merkleProof
    ) 
        external 
        nonReentrant 
        whenNotPaused 
        supportedToken(_message.token)
        validAddress(_message.recipient)
    {
        require(_message.targetChainId == block.chainid, "Wrong target chain");
        require(_message.amount > 0, "Amount must be positive");
        require(!processedNonces[_message.nonce], "Nonce already processed");
        require(_signatures.length >= requiredValidators, "Insufficient signatures");

        bytes32 messageHash = _getMessageHash(_message);
        require(!processedMessages[messageHash], "Message already processed");

        // Verify merkle proof for message
        bytes32 leaf = keccak256(abi.encodePacked(
            _message.sender,
            _message.recipient,
            _message.amount,
            _message.sourceChainId
        ));
        require(MerkleProof.verify(_merkleProof, _message.merkleRoot, leaf), "Invalid merkle proof");

        // Verify validator signatures
        _verifySignatures(messageHash, _signatures);

        // Mark as processed
        processedNonces[_message.nonce] = true;
        processedMessages[messageHash] = true;

        // Transfer tokens to recipient
        IERC20(_message.token).safeTransfer(_message.recipient, _message.amount);

        emit MessageProcessed(
            _message.nonce,
            _message.sourceChainId,
            _message.token,
            _message.recipient,
            _message.amount
        );
    }

    function voteForMessage(
        BridgeMessage calldata _message,
        bytes32[] calldata _merkleProof
    ) 
        external 
        onlyValidator 
        whenNotPaused 
    {
        bytes32 messageHash = _getMessageHash(_message);
        require(!hasVoted[messageHash][msg.sender], "Already voted");
        require(!processedMessages[messageHash], "Already processed");

        // Verify merkle proof
        bytes32 leaf = keccak256(abi.encodePacked(
            _message.sender,
            _message.recipient,
            _message.amount,
            _message.sourceChainId
        ));
        require(MerkleProof.verify(_merkleProof, _message.merkleRoot, leaf), "Invalid merkle proof");

        hasVoted[messageHash][msg.sender] = true;
        validatorVotes[messageHash]++;

        // Auto-process if enough votes
        if (validatorVotes[messageHash] >= requiredValidators) {
            _autoProcessMessage(_message);
        }
    }

    function addValidator(address _validator) 
        external 
        onlyAdmin 
        validAddress(_validator) 
    {
        require(!hasRole(VALIDATOR_ROLE, _validator), "Already a validator");
        
        _grantRole(VALIDATOR_ROLE, _validator);
        totalValidators++;
        
        emit ValidatorAdded(_validator);
    }

    function removeValidator(address _validator) 
        external 
        onlyAdmin 
        validAddress(_validator) 
    {
        require(hasRole(VALIDATOR_ROLE, _validator), "Not a validator");
        require(totalValidators > requiredValidators, "Cannot remove validator");
        
        _revokeRole(VALIDATOR_ROLE, _validator);
        totalValidators--;
        
        emit ValidatorRemoved(_validator);
    }

    function setRequiredValidators(uint256 _required) 
        external 
        onlyAdmin 
    {
        require(_required > 0 && _required <= totalValidators, "Invalid required validators");
        requiredValidators = _required;
    }

    function addSupportedToken(address _token) 
        external 
        onlyAdmin 
        validAddress(_token) 
    {
        supportedTokens[_token] = true;
        rateLimits[_token] = RateLimit({
            amount: 0,
            windowStart: block.timestamp,
            windowDuration: RATE_LIMIT_WINDOW,
            maxAmount: defaultMaxAmount
        });
        
        emit TokenSupported(_token);
    }

    function addSupportedChain(uint256 _chainId) 
        external 
        onlyAdmin 
    {
        require(_chainId != 0, "Invalid chain ID");
        require(_chainId != block.chainid, "Cannot add current chain");
        
        supportedChains[_chainId] = true;
        emit ChainSupported(_chainId);
    }

    function setTokenRateLimit(address _token, uint256 _maxAmount) 
        external 
        onlyAdmin 
        supportedToken(_token) 
    {
        require(_maxAmount > 0, "Max amount must be positive");
        rateLimits[_token].maxAmount = _maxAmount;
    }

    function pause() external {
        require(hasRole(PAUSER_ROLE, msg.sender), "Not authorized to pause");
        _pause();
    }

    function unpause() external onlyAdmin {
        _unpause();
    }

    function emergencyWithdraw(address _token, uint256 _amount) 
        external 
        onlyAdmin 
        validAddress(_token) 
    {
        require(_amount > 0, "Amount must be positive");
        IERC20(_token).safeTransfer(msg.sender, _amount);
    }

    function _checkRateLimit(address _token, uint256 _amount) private {
        RateLimit storage limit = rateLimits[_token];
        
        // Reset window if expired
        if (block.timestamp >= limit.windowStart + limit.windowDuration) {
            limit.amount = 0;
            limit.windowStart = block.timestamp;
        }
        
        require(limit.amount + _amount <= limit.maxAmount, "Rate limit exceeded");
        limit.amount += _amount;
    }

    function _getMessageHash(BridgeMessage calldata _message) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(
            _message.nonce,
            _message.sourceChainId,
            _message.targetChainId,
            _message.token,
            _message.sender,
            _message.recipient,
            _message.amount,
            _message.merkleRoot,
            _message.blockNumber
        ));
    }

    function _verifySignatures(bytes32 _messageHash, bytes[] calldata _signatures) private view {
        bytes32 ethSignedMessageHash = _messageHash.toEthSignedMessageHash();
        address[] memory signers = new address[](_signatures.length);
        
        for (uint256 i = 0; i < _signatures.length; i++) {
            address signer = ethSignedMessageHash.recover(_signatures[i]);
            require(hasRole(VALIDATOR_ROLE, signer), "Invalid validator signature");
            
            // Check for duplicate signers
            for (uint256 j = 0; j < i; j++) {
                require(signers[j] != signer, "Duplicate signature");
            }
            signers[i] = signer;
        }
    }

    function _autoProcessMessage(BridgeMessage calldata _message) private {
        require(_message.targetChainId == block.chainid, "Wrong target chain");
        require(!processedNonces[_message.nonce], "Nonce already processed");
        
        bytes32 messageHash = _getMessageHash(_message);
        require(!processedMessages[messageHash], "Message already processed");
        
        processedNonces[_message.nonce] = true;
        processedMessages[messageHash] = true;
        
        IERC20(_message.token).safeTransfer(_message.recipient, _message.amount);
        
        emit MessageProcessed(
            _message.nonce,
            _message.sourceChainId,
            _message.token,
            _message.recipient,
            _message.amount
        );
    }

    function getValidatorVotes(BridgeMessage calldata _message) external view returns (uint256) {
        bytes32 messageHash = _getMessageHash(_message);
        return validatorVotes[messageHash];
    }

    function isMessageProcessed(BridgeMessage calldata _message) external view returns (bool) {
        bytes32 messageHash = _getMessageHash(_message);
        return processedMessages[messageHash];
    }

    function getRateLimit(address _token) external view returns (RateLimit memory) {
        return rateLimits[_token];
    }
}