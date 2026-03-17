// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract NaiveBridgeRelayer {
    // ============ Types ============
    struct Message {
        uint256 sourceChainId;
        address sourceSender;
        address payable target;
        uint256 value; // native ETH to forward to target
        bytes data;    // calldata for target
        uint256 nonce; // unique per (sourceChainId, sourceSender)
    }

    // ============ Events ============
    event MessageRelayed(
        bytes32 indexed messageId,
        uint256 indexed sourceChainId,
        address indexed sourceSender,
        address target,
        uint256 value,
        uint256 nonce,
        bool success,
        bytes returnData
    );

    event TrustedSenderSet(uint256 indexed chainId, address indexed sender, bool allowed);
    event TargetAllowedSet(address indexed target, bool allowed);
    event AllowAnySourceSet(bool allowed);
    event AllowAnyTargetSet(bool allowed);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event Withdrawn(address indexed to, uint256 amount);

    // ============ Storage ============
    address public owner;

    // Trust controls
    bool public allowAnySource; // if true, accepts any (chainId, sourceSender)
    bool public allowAnyTarget = true; // if true, can call any target
    mapping(uint256 => mapping(address => bool)) public trustedSenders; // chainId => sourceSender => allowed
    mapping(address => bool) public allowedTargets; // target => allowed

    // Replay protection
    mapping(bytes32 => bool) public processed; // messageId => processed

    // ============ Modifiers ============
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier nonReentrant() {
        require(_status != _ENTERED, "Reentrancy");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status = _NOT_ENTERED;

    // ============ Constructor ============
    constructor(address initialOwner) {
        require(initialOwner != address(0), "Owner=0");
        owner = initialOwner;
        emit OwnershipTransferred(address(0), initialOwner);
    }

    // ============ Admin ============
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Owner=0");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function setAllowAnySource(bool allowed) external onlyOwner {
        allowAnySource = allowed;
        emit AllowAnySourceSet(allowed);
    }

    function setAllowAnyTarget(bool allowed) external onlyOwner {
        allowAnyTarget = allowed;
        emit AllowAnyTargetSet(allowed);
    }

    function setTrustedSender(uint256 chainId, address sender, bool allowed) external onlyOwner {
        trustedSenders[chainId][sender] = allowed;
        emit TrustedSenderSet(chainId, sender, allowed);
    }

    function setAllowedTarget(address target, bool allowed) external onlyOwner {
        allowedTargets[target] = allowed;
        emit TargetAllowedSet(target, allowed);
    }

    // Rescue/ops
    function withdraw(address payable to, uint256 amount) external onlyOwner {
        require(to != address(0), "to=0");
        require(address(this).balance >= amount, "Insufficient balance");
        (bool s, ) = to.call{value: amount}("");
        require(s, "Withdraw failed");
        emit Withdrawn(to, amount);
    }

    // ============ Core Relayer ============
    function relay(Message calldata m) external payable nonReentrant returns (bytes memory returnData) {
        require(allowAnySource || trustedSenders[m.sourceChainId][m.sourceSender], "Untrusted source");
        require(allowAnyTarget || allowedTargets[m.target], "Target not allowed");

        bytes32 id = computeMessageId(m);
        require(!processed[id], "Already processed");
        require(msg.value == m.value, "Value mismatch");

        // Mark processed before external call to prevent reentrancy-based replays
        processed[id] = true;

        (bool success, bytes memory data) = m.target.call{value: m.value}(m.data);

        emit MessageRelayed(
            id,
            m.sourceChainId,
            m.sourceSender,
            m.target,
            m.value,
            m.nonce,
            success,
            data
        );

        // Do not revert on target failure; message is considered delivered.
        returnData = data;
    }

    // ============ Views / Helpers ============
    function computeMessageId(Message calldata m) public pure returns (bytes32) {
        return keccak256(
            abi.encode(
                m.sourceChainId,
                m.sourceSender,
                m.target,
                m.value,
                keccak256(m.data),
                m.nonce
            )
        );
    }

    // Accept native ETH
    receive() external payable {}
}