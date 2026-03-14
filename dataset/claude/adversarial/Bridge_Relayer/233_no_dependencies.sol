// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract BridgeRelayer {
    struct Message {
        uint256 sourceChainId;
        uint256 destChainId;
        address sender;
        address recipient;
        uint256 amount;
        bytes data;
        uint256 nonce;
        uint256 timestamp;
    }

    struct RelayRequest {
        bytes32 messageHash;
        uint256 confirmations;
        bool executed;
        mapping(address => bool) hasConfirmed;
    }

    address public owner;
    uint256 public requiredConfirmations;
    uint256 public relayerCount;
    uint256 public nonce;
    uint256 public relayFee;

    mapping(address => bool) public isRelayer;
    mapping(bytes32 => RelayRequest) public relayRequests;
    mapping(bytes32 => Message) public messages;
    mapping(bytes32 => bool) public processedMessages;

    event MessageSent(
        bytes32 indexed messageHash,
        uint256 sourceChainId,
        uint256 destChainId,
        address indexed sender,
        address indexed recipient,
        uint256 amount,
        bytes data,
        uint256 nonce
    );

    event MessageConfirmed(bytes32 indexed messageHash, address indexed relayer, uint256 confirmations);
    event MessageExecuted(bytes32 indexed messageHash, address indexed recipient, uint256 amount);
    event RelayerAdded(address indexed relayer);
    event RelayerRemoved(address indexed relayer);
    event RequiredConfirmationsUpdated(uint256 oldValue, uint256 newValue);
    event RelayFeeUpdated(uint256 oldFee, uint256 newFee);
    event Deposited(address indexed sender, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier onlyRelayer() {
        require(isRelayer[msg.sender], "Not relayer");
        _;
    }

    constructor(uint256 _requiredConfirmations, uint256 _relayFee) {
        owner = msg.sender;
        requiredConfirmations = _requiredConfirmations;
        relayFee = _relayFee;
    }

    receive() external payable {
        emit Deposited(msg.sender, msg.value);
    }

    function addRelayer(address _relayer) external onlyOwner {
        require(_relayer != address(0), "Invalid address");
        require(!isRelayer[_relayer], "Already relayer");
        isRelayer[_relayer] = true;
        relayerCount++;
        emit RelayerAdded(_relayer);
    }

    function removeRelayer(address _relayer) external onlyOwner {
        require(isRelayer[_relayer], "Not a relayer");
        isRelayer[_relayer] = false;
        relayerCount--;
        require(relayerCount >= requiredConfirmations, "Would break quorum");
        emit RelayerRemoved(_relayer);
    }

    function setRequiredConfirmations(uint256 _required) external onlyOwner {
        require(_required > 0 && _required <= relayerCount, "Invalid confirmations");
        uint256 old = requiredConfirmations;
        requiredConfirmations = _required;
        emit RequiredConfirmationsUpdated(old, _required);
    }

    function setRelayFee(uint256 _fee) external onlyOwner {
        uint256 old = relayFee;
        relayFee = _fee;
        emit RelayFeeUpdated(old, _fee);
    }

    function sendMessage(
        uint256 _destChainId,
        address _recipient,
        bytes calldata _data
    ) external payable returns (bytes32) {
        require(msg.value >= relayFee, "Insufficient fee");
        require(_recipient != address(0), "Invalid recipient");

        uint256 currentNonce = nonce++;
        uint256 amount = msg.value - relayFee;

        bytes32 messageHash = keccak256(
            abi.encodePacked(
                block.chainid,
                _destChainId,
                msg.sender,
                _recipient,
                amount,
                _data,
                currentNonce
            )
        );

        messages[messageHash] = Message({
            sourceChainId: block.chainid,
            destChainId: _destChainId,
            sender: msg.sender,
            recipient: _recipient,
            amount: amount,
            data: _data,
            nonce: currentNonce,
            timestamp: block.timestamp
        });

        emit MessageSent(
            messageHash,
            block.chainid,
            _destChainId,
            msg.sender,
            _recipient,
            amount,
            _data,
            currentNonce
        );

        return messageHash;
    }

    function confirmMessage(
        bytes32 _messageHash,
        uint256 _sourceChainId,
        address _sender,
        address _recipient,
        uint256 _amount,
        bytes calldata _data,
        uint256 _nonce
    ) external onlyRelayer {
        bytes32 computedHash = keccak256(
            abi.encodePacked(
                _sourceChainId,
                block.chainid,
                _sender,
                _recipient,
                _amount,
                _data,
                _nonce
            )
        );
        require(computedHash == _messageHash, "Hash mismatch");
        require(!processedMessages[_messageHash], "Already processed");

        RelayRequest storage request = relayRequests[_messageHash];
        require(!request.hasConfirmed[msg.sender], "Already confirmed");

        if (request.messageHash == bytes32(0)) {
            request.messageHash = _messageHash;
            messages[_messageHash] = Message({
                sourceChainId: _sourceChainId,
                destChainId: block.chainid,
                sender: _sender,
                recipient: _recipient,
                amount: _amount,
                data: _data,
                nonce: _nonce,
                timestamp: block.timestamp
            });
        }

        request.hasConfirmed[msg.sender] = true;
        request.confirmations++;

        emit MessageConfirmed(_messageHash, msg.sender, request.confirmations);

        if (request.confirmations >= requiredConfirmations && !request.executed) {
            _executeMessage(_messageHash);
        }
    }

    function _executeMessage(bytes32 _messageHash) internal {
        RelayRequest storage request = relayRequests[_messageHash];
        require(!request.executed, "Already executed");
        require(request.confirmations >= requiredConfirmations, "Not enough confirmations");

        request.executed = true;
        processedMessages[_messageHash] = true;

        Message storage message = messages[_messageHash];

        if (message.amount > 0) {
            require(address(this).balance >= message.amount, "Insufficient bridge balance");
            (bool success, ) = payable(message.recipient).call{value: message.amount}("");
            require(success, "Transfer failed");
        }

        if (message.data.length > 0) {
            (bool success, ) = message.recipient.call(message.data);
            require(success, "Callback failed");
        }

        emit MessageExecuted(_messageHash, message.recipient, message.amount);
    }

    function getConfirmationCount(bytes32 _messageHash) external view returns (uint256) {
        return relayRequests[_messageHash].confirmations;
    }

    function hasRelayerConfirmed(bytes32 _messageHash, address _relayer) external view returns (bool) {
        return relayRequests[_messageHash].hasConfirmed[_relayer];
    }

    function isMessageProcessed(bytes32 _messageHash) external view returns (bool) {
        return processedMessages[_messageHash];
    }

    function withdrawFees(address payable _to) external onlyOwner {
        require(_to != address(0), "Invalid address");
        uint256 balance = address(this).balance;
        require(balance > 0, "No fees");
        (bool success, ) = _to.call{value: balance}("");
        require(success, "Withdraw failed");
    }

    function transferOwnership(address _newOwner) external onlyOwner {
        require(_newOwner != address(0), "Invalid address");
        owner = _newOwner;
    }
}