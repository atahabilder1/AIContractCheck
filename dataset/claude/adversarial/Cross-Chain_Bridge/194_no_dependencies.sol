// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CrossChainBridge {
    address public owner;
    address public relayer;
    uint256 public nonce;
    uint256 public requiredConfirmations;
    uint256 public dailyLimit;
    uint256 public dailyTransferred;
    uint256 public lastResetDay;

    enum TokenType { NATIVE, ERC20 }

    struct BridgeRequest {
        address sender;
        address recipient;
        uint256 amount;
        uint256 destChainId;
        uint256 nonce;
        TokenType tokenType;
        address tokenAddress;
        bool processed;
    }

    struct ValidatorSet {
        address[] validators;
        mapping(address => bool) isValidator;
        uint256 threshold;
    }

    ValidatorSet private validatorSet;

    mapping(bytes32 => BridgeRequest) public bridgeRequests;
    mapping(bytes32 => mapping(address => bool)) public confirmations;
    mapping(bytes32 => uint256) public confirmationCount;
    mapping(bytes32 => bool) public processedHashes;
    mapping(address => bool) public supportedTokens;
    mapping(address => bool) public blacklisted;

    bool public paused;

    event Deposit(
        bytes32 indexed requestHash,
        address indexed sender,
        address indexed recipient,
        uint256 amount,
        uint256 destChainId,
        uint256 nonce,
        TokenType tokenType,
        address tokenAddress
    );

    event Withdrawal(
        bytes32 indexed requestHash,
        address indexed recipient,
        uint256 amount,
        TokenType tokenType,
        address tokenAddress
    );

    event ValidatorConfirmed(bytes32 indexed requestHash, address indexed validator);
    event ValidatorAdded(address indexed validator);
    event ValidatorRemoved(address indexed validator);
    event TokenAdded(address indexed token);
    event TokenRemoved(address indexed token);
    event Paused(address indexed by);
    event Unpaused(address indexed by);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier onlyValidator() {
        require(validatorSet.isValidator[msg.sender], "Not validator");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "Bridge is paused");
        _;
    }

    modifier notBlacklisted(address account) {
        require(!blacklisted[account], "Address blacklisted");
        _;
    }

    constructor(address[] memory _validators, uint256 _threshold, uint256 _dailyLimit) {
        require(_validators.length >= _threshold, "Invalid threshold");
        require(_threshold > 0, "Threshold must be > 0");

        owner = msg.sender;
        requiredConfirmations = _threshold;
        dailyLimit = _dailyLimit;
        lastResetDay = block.timestamp / 1 days;

        validatorSet.threshold = _threshold;
        for (uint256 i = 0; i < _validators.length; i++) {
            require(_validators[i] != address(0), "Invalid validator");
            require(!validatorSet.isValidator[_validators[i]], "Duplicate validator");
            validatorSet.validators.push(_validators[i]);
            validatorSet.isValidator[_validators[i]] = true;
        }
    }

    function depositNative(address _recipient, uint256 _destChainId) external payable whenNotPaused notBlacklisted(msg.sender) {
        require(msg.value > 0, "Amount must be > 0");
        require(_recipient != address(0), "Invalid recipient");
        require(_destChainId != block.chainid, "Same chain");

        _checkDailyLimit(msg.value);

        uint256 currentNonce = nonce++;
        bytes32 requestHash = keccak256(
            abi.encodePacked(msg.sender, _recipient, msg.value, _destChainId, currentNonce, block.chainid)
        );

        bridgeRequests[requestHash] = BridgeRequest({
            sender: msg.sender,
            recipient: _recipient,
            amount: msg.value,
            destChainId: _destChainId,
            nonce: currentNonce,
            tokenType: TokenType.NATIVE,
            tokenAddress: address(0),
            processed: false
        });

        emit Deposit(requestHash, msg.sender, _recipient, msg.value, _destChainId, currentNonce, TokenType.NATIVE, address(0));
    }

    function depositERC20(address _token, uint256 _amount, address _recipient, uint256 _destChainId) external whenNotPaused notBlacklisted(msg.sender) {
        require(_amount > 0, "Amount must be > 0");
        require(_recipient != address(0), "Invalid recipient");
        require(supportedTokens[_token], "Token not supported");
        require(_destChainId != block.chainid, "Same chain");

        _checkDailyLimit(_amount);

        (bool success, bytes memory data) = _token.call(
            abi.encodeWithSignature("transferFrom(address,address,uint256)", msg.sender, address(this), _amount)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "Transfer failed");

        uint256 currentNonce = nonce++;
        bytes32 requestHash = keccak256(
            abi.encodePacked(msg.sender, _recipient, _amount, _destChainId, currentNonce, block.chainid, _token)
        );

        bridgeRequests[requestHash] = BridgeRequest({
            sender: msg.sender,
            recipient: _recipient,
            amount: _amount,
            destChainId: _destChainId,
            nonce: currentNonce,
            tokenType: TokenType.ERC20,
            tokenAddress: _token,
            processed: false
        });

        emit Deposit(requestHash, msg.sender, _recipient, _amount, _destChainId, currentNonce, TokenType.ERC20, _token);
    }

    function confirmWithdrawal(
        bytes32 _requestHash,
        address _recipient,
        uint256 _amount,
        TokenType _tokenType,
        address _tokenAddress
    ) external onlyValidator whenNotPaused notBlacklisted(_recipient) {
        require(!processedHashes[_requestHash], "Already processed");
        require(!confirmations[_requestHash][msg.sender], "Already confirmed");

        confirmations[_requestHash][msg.sender] = true;
        confirmationCount[_requestHash]++;

        emit ValidatorConfirmed(_requestHash, msg.sender);

        if (confirmationCount[_requestHash] >= validatorSet.threshold) {
            processedHashes[_requestHash] = true;

            if (_tokenType == TokenType.NATIVE) {
                (bool sent, ) = _recipient.call{value: _amount}("");
                require(sent, "Native transfer failed");
            } else {
                (bool success, bytes memory data) = _tokenAddress.call(
                    abi.encodeWithSignature("transfer(address,uint256)", _recipient, _amount)
                );
                require(success && (data.length == 0 || abi.decode(data, (bool))), "Token transfer failed");
            }

            emit Withdrawal(_requestHash, _recipient, _amount, _tokenType, _tokenAddress);
        }
    }

    function _checkDailyLimit(uint256 _amount) internal {
        uint256 currentDay = block.timestamp / 1 days;
        if (currentDay > lastResetDay) {
            dailyTransferred = 0;
            lastResetDay = currentDay;
        }
        dailyTransferred += _amount;
        require(dailyTransferred <= dailyLimit, "Daily limit exceeded");
    }

    function addValidator(address _validator) external onlyOwner {
        require(_validator != address(0), "Invalid address");
        require(!validatorSet.isValidator[_validator], "Already validator");
        validatorSet.validators.push(_validator);
        validatorSet.isValidator[_validator] = true;
        emit ValidatorAdded(_validator);
    }

    function removeValidator(address _validator) external onlyOwner {
        require(validatorSet.isValidator[_validator], "Not a validator");
        require(validatorSet.validators.length - 1 >= validatorSet.threshold, "Below threshold");
        validatorSet.isValidator[_validator] = false;

        for (uint256 i = 0; i < validatorSet.validators.length; i++) {
            if (validatorSet.validators[i] == _validator) {
                validatorSet.validators[i] = validatorSet.validators[validatorSet.validators.length - 1];
                validatorSet.validators.pop();
                break;
            }
        }
        emit ValidatorRemoved(_validator);
    }

    function setThreshold(uint256 _threshold) external onlyOwner {
        require(_threshold > 0, "Invalid threshold");
        require(_threshold <= validatorSet.validators.length, "Threshold too high");
        validatorSet.threshold = _threshold;
        requiredConfirmations = _threshold;
    }

    function addSupportedToken(address _token) external onlyOwner {
        require(_token != address(0), "Invalid token");
        supportedTokens[_token] = true;
        emit TokenAdded(_token);
    }

    function removeSupportedToken(address _token) external onlyOwner {
        supportedTokens[_token] = false;
        emit TokenRemoved(_token);
    }

    function setBlacklist(address _account, bool _status) external onlyOwner {
        blacklisted[_account] = _status;
    }

    function setDailyLimit(uint256 _limit) external onlyOwner {
        dailyLimit = _limit;
    }

    function pause() external onlyOwner {
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOwner {
        paused = false;
        emit Unpaused(msg.sender);
    }

    function transferOwnership(address _newOwner) external onlyOwner {
        require(_newOwner != address(0), "Invalid address");
        owner = _newOwner;
    }

    function getValidators() external view returns (address[] memory) {
        return validatorSet.validators;
    }

    function getValidatorCount() external view returns (uint256) {
        return validatorSet.validators.length;
    }

    function emergencyWithdrawNative(uint256 _amount) external onlyOwner {
        require(paused, "Must be paused");
        (bool sent, ) = owner.call{value: _amount}("");
        require(sent, "Transfer failed");
    }

    function emergencyWithdrawERC20(address _token, uint256 _amount) external onlyOwner {
        require(paused, "Must be paused");
        (bool success, bytes memory data) = _token.call(
            abi.encodeWithSignature("transfer(address,uint256)", owner, _amount)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "Transfer failed");
    }

    receive() external payable {}
}