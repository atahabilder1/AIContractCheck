// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract BridgeRelayer {
    struct Message {
        uint256 sourceChainId;
        uint256 destChainId;
        address sender;
        address recipient;
        uint256 amount;
        uint256 nonce;
        bytes data;
    }

    address public owner;
    uint256 public requiredConfirmations;
    uint256 public nonce;

    mapping(address => bool) public relayers;
    uint256 public relayerCount;

    mapping(bytes32 => bool) public processedMessages;
    mapping(bytes32 => mapping(address => bool)) public confirmations;
    mapping(bytes32 => uint256) public confirmationCount;

    mapping(address => uint256) public deposits;

    event Deposited(address indexed sender, uint256 amount, uint256 destChainId, uint256 nonce);
    event MessageSubmitted(bytes32 indexed messageHash, address indexed relayer);
    event MessageExecuted(bytes32 indexed messageHash, address indexed recipient, uint256 amount);
    event RelayerAdded(address indexed relayer);
    event RelayerRemoved(address indexed relayer);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier onlyRelayer() {
        require(relayers[msg.sender], "Not relayer");
        _;
    }

    constructor(address[] memory _relayers, uint256 _requiredConfirmations) {
        require(_relayers.length >= _requiredConfirmations, "Not enough relayers");
        require(_requiredConfirmations > 0, "Need at least 1 confirmation");

        owner = msg.sender;
        requiredConfirmations = _requiredConfirmations;

        for (uint256 i = 0; i < _relayers.length; i++) {
            require(_relayers[i] != address(0), "Invalid relayer");
            require(!relayers[_relayers[i]], "Duplicate relayer");
            relayers[_relayers[i]] = true;
            relayerCount++;
            emit RelayerAdded(_relayers[i]);
        }
    }

    receive() external payable {}

    function deposit(uint256 destChainId, address recipient) external payable {
        require(msg.value > 0, "Zero amount");
        require(recipient != address(0), "Invalid recipient");

        uint256 currentNonce = nonce++;
        deposits[msg.sender] += msg.value;

        emit Deposited(msg.sender, msg.value, destChainId, currentNonce);
    }

    function submitMessage(
        uint256 sourceChainId,
        address sender,
        address recipient,
        uint256 amount,
        uint256 msgNonce,
        bytes calldata data
    ) external onlyRelayer {
        Message memory message = Message({
            sourceChainId: sourceChainId,
            destChainId: block.chainid,
            sender: sender,
            recipient: recipient,
            amount: amount,
            nonce: msgNonce,
            data: data
        });

        bytes32 messageHash = hashMessage(message);
        require(!processedMessages[messageHash], "Already processed");
        require(!confirmations[messageHash][msg.sender], "Already confirmed");

        confirmations[messageHash][msg.sender] = true;
        confirmationCount[messageHash]++;

        emit MessageSubmitted(messageHash, msg.sender);

        if (confirmationCount[messageHash] >= requiredConfirmations) {
            processedMessages[messageHash] = true;
            _executeMessage(messageHash, recipient, amount, data);
        }
    }

    function _executeMessage(
        bytes32 messageHash,
        address recipient,
        uint256 amount,
        bytes memory data
    ) internal {
        if (amount > 0) {
            require(address(this).balance >= amount, "Insufficient bridge balance");
            (bool success, ) = payable(recipient).call{value: amount}(data);
            require(success, "Transfer failed");
        }

        emit MessageExecuted(messageHash, recipient, amount);
    }

    function hashMessage(Message memory message) public pure returns (bytes32) {
        return keccak256(abi.encode(
            message.sourceChainId,
            message.destChainId,
            message.sender,
            message.recipient,
            message.amount,
            message.nonce,
            keccak256(message.data)
        ));
    }

    function addRelayer(address relayer) external onlyOwner {
        require(relayer != address(0), "Invalid relayer");
        require(!relayers[relayer], "Already relayer");
        relayers[relayer] = true;
        relayerCount++;
        emit RelayerAdded(relayer);
    }

    function removeRelayer(address relayer) external onlyOwner {
        require(relayers[relayer], "Not a relayer");
        require(relayerCount - 1 >= requiredConfirmations, "Would break threshold");
        relayers[relayer] = false;
        relayerCount--;
        emit RelayerRemoved(relayer);
    }

    function setRequiredConfirmations(uint256 _required) external onlyOwner {
        require(_required > 0 && _required <= relayerCount, "Invalid threshold");
        requiredConfirmations = _required;
    }

    function fundBridge() external payable {
        require(msg.value > 0, "Zero amount");
    }
}