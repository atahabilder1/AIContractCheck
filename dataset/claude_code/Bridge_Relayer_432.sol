// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Bridge Relayer Contract
contract BridgeRelayer {
    address public owner;
    address public bridge;
    uint256 public minConfirmations;

    mapping(address => bool) public validators;
    mapping(bytes32 => uint256) public confirmations;
    mapping(bytes32 => mapping(address => bool)) public hasConfirmed;
    mapping(bytes32 => bool) public executed;

    uint256 public validatorCount;

    event ValidatorAdded(address indexed validator);
    event ValidatorRemoved(address indexed validator);
    event MessageConfirmed(bytes32 indexed messageId, address indexed validator);
    event MessageExecuted(bytes32 indexed messageId);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier onlyValidator() {
        require(validators[msg.sender], "Not validator");
        _;
    }

    constructor(address _bridge, uint256 _minConfirmations) {
        owner = msg.sender;
        bridge = _bridge;
        minConfirmations = _minConfirmations;
        validators[msg.sender] = true;
        validatorCount = 1;
    }

    function addValidator(address validator) external onlyOwner {
        require(!validators[validator], "Already validator");
        validators[validator] = true;
        validatorCount++;
        emit ValidatorAdded(validator);
    }

    function removeValidator(address validator) external onlyOwner {
        require(validators[validator], "Not validator");
        require(validatorCount > minConfirmations, "Too few validators");
        validators[validator] = false;
        validatorCount--;
        emit ValidatorRemoved(validator);
    }

    function confirmMessage(bytes32 messageId) external onlyValidator {
        require(!hasConfirmed[messageId][msg.sender], "Already confirmed");
        require(!executed[messageId], "Already executed");

        hasConfirmed[messageId][msg.sender] = true;
        confirmations[messageId]++;

        emit MessageConfirmed(messageId, msg.sender);
    }

    function executeMessage(
        bytes32 messageId,
        address target,
        bytes calldata data
    ) external onlyValidator {
        require(confirmations[messageId] >= minConfirmations, "Not enough confirmations");
        require(!executed[messageId], "Already executed");

        executed[messageId] = true;

        (bool success, ) = target.call(data);
        require(success, "Execution failed");

        emit MessageExecuted(messageId);
    }

    function setMinConfirmations(uint256 _minConfirmations) external onlyOwner {
        require(_minConfirmations <= validatorCount, "Too high");
        require(_minConfirmations > 0, "Must be > 0");
        minConfirmations = _minConfirmations;
    }

    function setBridge(address _bridge) external onlyOwner {
        bridge = _bridge;
    }

    function getConfirmationCount(bytes32 messageId) external view returns (uint256) {
        return confirmations[messageId];
    }

    function isConfirmed(bytes32 messageId) external view returns (bool) {
        return confirmations[messageId] >= minConfirmations;
    }
}
