// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error NotOwner();

    constructor() {
        _transferOwnership(msg.sender);
    }

    modifier onlyOwner() {
        if (msg.sender != _owner) revert NotOwner();
        _;
    }

    function owner() public view returns (address) {
        return _owner;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "new owner is zero");
        _transferOwnership(newOwner);
    }

    function renounceOwnership() external onlyOwner {
        _transferOwnership(address(0));
    }

    function _transferOwnership(address newOwner) internal {
        address old = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(old, newOwner);
    }
}

contract MultiRelayerConsensus is Ownable {
    // Errors
    error NotRelayer();
    error AlreadySubmitted();
    error AlreadyApproved();
    error InvalidRelayers();
    error InvalidThreshold();
    error RelayerExists();
    error RelayerDoesNotExist();

    // Events
    event RelayerAdded(address indexed relayer);
    event RelayerRemoved(address indexed relayer);
    event ThresholdUpdated(uint256 newThreshold);
    event MessageSubmitted(bytes32 indexed messageId, address indexed relayer, uint256 approvals, uint256 threshold);
    event MessageApproved(bytes32 indexed messageId);

    struct MessageStatus {
        uint32 approvals;
        bool approved;
    }

    // State
    mapping(address => bool) public isRelayer;
    uint256 public relayerCount;
    uint256 public threshold;

    mapping(bytes32 => MessageStatus) private _status;
    mapping(bytes32 => mapping(address => bool)) private _approvedBy;

    constructor(address[] memory relayers, uint256 requiredThreshold) {
        if (relayers.length == 0) revert InvalidRelayers();

        // ensure unique and non-zero relayers
        for (uint256 i = 0; i < relayers.length; i++) {
            address r = relayers[i];
            if (r == address(0)) revert InvalidRelayers();
            if (isRelayer[r]) revert InvalidRelayers();
            isRelayer[r] = true;
            relayerCount++;
            emit RelayerAdded(r);
        }

        if (requiredThreshold == 0 || requiredThreshold > relayerCount) revert InvalidThreshold();
        threshold = requiredThreshold;
        emit ThresholdUpdated(requiredThreshold);
    }

    modifier onlyRelayer() {
        if (!isRelayer[msg.sender]) revert NotRelayer();
        _;
    }

    // Submit arbitrary bytes message; messageId = keccak256(message)
    function submitMessage(bytes calldata message) external onlyRelayer returns (bytes32 messageId, uint256 approvals) {
        messageId = keccak256(message);
        approvals = _approve(messageId);
    }

    // Submit a precomputed messageId (bytes32)
    function submitMessageHash(bytes32 messageId) external onlyRelayer returns (uint256 approvals) {
        approvals = _approve(messageId);
    }

    function _approve(bytes32 messageId) internal returns (uint256 approvals) {
        if (_status[messageId].approved) revert AlreadyApproved();
        if (_approvedBy[messageId][msg.sender]) revert AlreadySubmitted();

        _approvedBy[messageId][msg.sender] = true;

        uint32 newApprovals = _status[messageId].approvals + 1;
        _status[messageId].approvals = newApprovals;

        emit MessageSubmitted(messageId, msg.sender, newApprovals, threshold);

        if (newApprovals >= threshold) {
            _status[messageId].approved = true;
            emit MessageApproved(messageId);
        }

        approvals = newApprovals;
    }

    // View helpers
    function isMessageApproved(bytes32 messageId) external view returns (bool) {
        return _status[messageId].approved;
    }

    function messageApprovals(bytes32 messageId) external view returns (uint256) {
        return _status[messageId].approvals;
    }

    function hasRelayerApproved(bytes32 messageId, address relayer) external view returns (bool) {
        return _approvedBy[messageId][relayer];
    }

    function messageIdFrom(bytes calldata message) external pure returns (bytes32) {
        return keccak256(message);
    }

    // Admin: manage relayers and threshold
    function addRelayer(address relayer) external onlyOwner {
        if (relayer == address(0)) revert InvalidRelayers();
        if (isRelayer[relayer]) revert RelayerExists();
        isRelayer[relayer] = true;
        relayerCount += 1;
        emit RelayerAdded(relayer);
        // threshold remains unchanged; ensure it's still valid
        if (threshold == 0 || threshold > relayerCount) revert InvalidThreshold();
    }

    function removeRelayer(address relayer) external onlyOwner {
        if (!isRelayer[relayer]) revert RelayerDoesNotExist();
        isRelayer[relayer] = false;
        relayerCount -= 1;
        emit RelayerRemoved(relayer);
        if (relayerCount == 0 || threshold == 0 || threshold > relayerCount) revert InvalidThreshold();
    }

    function setThreshold(uint256 newThreshold) external onlyOwner {
        if (newThreshold == 0 || newThreshold > relayerCount) revert InvalidThreshold();
        threshold = newThreshold;
        emit ThresholdUpdated(newThreshold);
    }
}