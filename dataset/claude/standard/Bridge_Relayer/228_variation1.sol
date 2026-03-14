// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MultiRelayerConsensus {
    address public owner;
    uint256 public requiredConfirmations;
    mapping(address => bool) public isRelayer;
    address[] public relayers;

    struct Message {
        bytes32 messageHash;
        uint256 confirmations;
        bool executed;
        mapping(address => bool) confirmedBy;
    }

    mapping(bytes32 => Message) public messages;

    event RelayerAdded(address indexed relayer);
    event RelayerRemoved(address indexed relayer);
    event MessageSubmitted(bytes32 indexed messageId, address indexed relayer);
    event MessageConfirmed(bytes32 indexed messageId, uint256 confirmations);
    event MessageExecuted(bytes32 indexed messageId, address indexed target, bytes data);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier onlyRelayer() {
        require(isRelayer[msg.sender], "Not relayer");
        _;
    }

    constructor(address[] memory _relayers, uint256 _requiredConfirmations) {
        require(_relayers.length >= _requiredConfirmations, "Not enough relayers");
        require(_requiredConfirmations > 0, "Need at least 1 confirmation");

        owner = msg.sender;
        requiredConfirmations = _requiredConfirmations;

        for (uint256 i = 0; i < _relayers.length; i++) {
            require(_relayers[i] != address(0), "Zero address");
            require(!isRelayer[_relayers[i]], "Duplicate relayer");
            isRelayer[_relayers[i]] = true;
            relayers.push(_relayers[i]);
        }
    }

    function submitMessage(
        uint256 sourceChainId,
        address target,
        bytes calldata data,
        uint256 nonce
    ) external onlyRelayer {
        bytes32 messageHash = keccak256(abi.encodePacked(sourceChainId, target, data, nonce));
        bytes32 messageId = keccak256(abi.encodePacked(messageHash, block.chainid));

        Message storage message = messages[messageId];
        require(!message.executed, "Already executed");
        require(!message.confirmedBy[msg.sender], "Already confirmed");

        if (message.confirmations == 0) {
            message.messageHash = messageHash;
        }

        message.confirmedBy[msg.sender] = true;
        message.confirmations++;

        emit MessageSubmitted(messageId, msg.sender);
        emit MessageConfirmed(messageId, message.confirmations);

        if (message.confirmations >= requiredConfirmations) {
            message.executed = true;
            (bool success, ) = target.call(data);
            require(success, "Execution failed");
            emit MessageExecuted(messageId, target, data);
        }
    }

    function getConfirmationCount(bytes32 messageId) external view returns (uint256) {
        return messages[messageId].confirmations;
    }

    function isConfirmedBy(bytes32 messageId, address relayer) external view returns (bool) {
        return messages[messageId].confirmedBy[relayer];
    }

    function addRelayer(address relayer) external onlyOwner {
        require(relayer != address(0), "Zero address");
        require(!isRelayer[relayer], "Already relayer");
        isRelayer[relayer] = true;
        relayers.push(relayer);
        emit RelayerAdded(relayer);
    }

    function removeRelayer(address relayer) external onlyOwner {
        require(isRelayer[relayer], "Not relayer");
        require(relayers.length - 1 >= requiredConfirmations, "Would break threshold");
        isRelayer[relayer] = false;

        for (uint256 i = 0; i < relayers.length; i++) {
            if (relayers[i] == relayer) {
                relayers[i] = relayers[relayers.length - 1];
                relayers.pop();
                break;
            }
        }
        emit RelayerRemoved(relayer);
    }

    function setRequiredConfirmations(uint256 _required) external onlyOwner {
        require(_required > 0, "Need at least 1");
        require(_required <= relayers.length, "Exceeds relayer count");
        requiredConfirmations = _required;
    }

    function getRelayers() external view returns (address[] memory) {
        return relayers;
    }
}