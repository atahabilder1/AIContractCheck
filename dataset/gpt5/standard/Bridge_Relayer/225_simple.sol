// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IBridgeReceiver {
    function onMessage(
        uint256 srcChainId,
        address srcSender,
        bytes calldata data
    ) external;
}

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
}

contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        address sender = _msgSender();
        _owner = sender;
        emit OwnershipTransferred(address(0), sender);
    }

    modifier onlyOwner() {
        require(_msgSender() == _owner, "Ownable: not owner");
        _;
    }

    function owner() public view returns (address) {
        return _owner;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Ownable: zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

abstract contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status = _NOT_ENTERED;

    modifier nonReentrant() {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
}

contract BridgeRelayer is Ownable, ReentrancyGuard {
    struct Message {
        uint256 srcChainId;
        address srcSender;
        address target;
        bytes data;
        uint256 nonce;
        address relayer;
        uint64 timestamp;
        bool executed;
        bool cancelled;
    }

    // next message nonce (starts at 1 for clarity)
    uint256 public nextNonce = 1;

    // authorized relayers
    mapping(address => bool) public isRelayer;

    // messageId => Message
    mapping(bytes32 => Message) private _messages;

    event RelayerUpdated(address indexed relayer, bool approved);

    event MessageStored(
        bytes32 indexed messageId,
        uint256 indexed srcChainId,
        address indexed srcSender,
        address target,
        uint256 nonce,
        address relayer,
        bytes data
    );

    event MessageForwarded(
        bytes32 indexed messageId,
        address indexed target,
        bool success,
        bytes returnData
    );

    event MessageCancelled(bytes32 indexed messageId, address indexed canceller);

    modifier onlyRelayer() {
        require(isRelayer[_msgSender()], "BridgeRelayer: not relayer");
        _;
    }

    function setRelayer(address relayer, bool approved) external onlyOwner {
        require(relayer != address(0), "BridgeRelayer: zero address");
        isRelayer[relayer] = approved;
        emit RelayerUpdated(relayer, approved);
    }

    function computeMessageId(
        uint256 srcChainId,
        address srcSender,
        address target,
        bytes memory data,
        uint256 nonce
    ) public view returns (bytes32) {
        return keccak256(
            abi.encodePacked(address(this), srcChainId, srcSender, target, keccak256(data), nonce)
        );
    }

    function storeMessage(
        uint256 srcChainId,
        address srcSender,
        address target,
        bytes calldata data
    ) external onlyRelayer returns (bytes32 messageId, uint256 nonce) {
        require(target != address(0), "BridgeRelayer: target zero");
        nonce = nextNonce;
        unchecked {
            nextNonce = nonce + 1;
        }

        messageId = computeMessageId(srcChainId, srcSender, target, data, nonce);

        Message storage m = _messages[messageId];
        require(m.relayer == address(0), "BridgeRelayer: message exists");

        _messages[messageId] = Message({
            srcChainId: srcChainId,
            srcSender: srcSender,
            target: target,
            data: data,
            nonce: nonce,
            relayer: _msgSender(),
            timestamp: uint64(block.timestamp),
            executed: false,
            cancelled: false
        });

        emit MessageStored(messageId, srcChainId, srcSender, target, nonce, _msgSender(), data);
    }

    function forwardMessage(bytes32 messageId) public onlyRelayer nonReentrant returns (bool success, bytes memory ret) {
        Message storage m = _messages[messageId];
        require(m.relayer != address(0), "BridgeRelayer: unknown message");
        require(!m.executed, "BridgeRelayer: already executed");
        require(!m.cancelled, "BridgeRelayer: cancelled");

        // Effects before interaction
        m.executed = true;

        // If target implements IBridgeReceiver, it can decode src metadata.
        // Otherwise, it's a generic call with provided calldata.
        (success, ret) = m.target.call(m.data);

        emit MessageForwarded(messageId, m.target, success, ret);
    }

    function storeAndForward(
        uint256 srcChainId,
        address srcSender,
        address target,
        bytes calldata data
    ) external onlyRelayer nonReentrant returns (bytes32 messageId, bool success, bytes memory ret) {
        (messageId, ) = storeMessage(srcChainId, srcSender, target, data);
        (success, ret) = forwardMessage(messageId);
    }

    function batchForward(bytes32[] calldata messageIds) external onlyRelayer nonReentrant {
        uint256 len = messageIds.length;
        for (uint256 i = 0; i < len; ) {
            bytes32 id = messageIds[i];
            Message storage m = _messages[id];
            if (m.relayer != address(0) && !m.executed && !m.cancelled) {
                m.executed = true;
                (bool ok, bytes memory ret) = m.target.call(m.data);
                emit MessageForwarded(id, m.target, ok, ret);
            }
            unchecked {
                ++i;
            }
        }
    }

    function cancelMessage(bytes32 messageId) external onlyOwner {
        Message storage m = _messages[messageId];
        require(m.relayer != address(0), "BridgeRelayer: unknown message");
        require(!m.executed, "BridgeRelayer: already executed");
        require(!m.cancelled, "BridgeRelayer: already cancelled");
        m.cancelled = true;
        emit MessageCancelled(messageId, _msgSender());
    }

    function getMessage(bytes32 messageId) external view returns (Message memory) {
        return _messages[messageId];
    }

    function messageExists(bytes32 messageId) external view returns (bool) {
        return _messages[messageId].relayer != address(0);
    }
}