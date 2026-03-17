// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ICrossChainMessageReceiver {
    function onCrossChainMessage(
        uint256 srcChainId,
        address srcContract,
        address from,
        bytes calldata message
    ) external;
}

contract Ownable {
    address public owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        owner = msg.sender;
        emit OwnershipTransferred(address(0), owner);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "NOT_OWNER");
        _;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "ZERO_ADDR");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
}

contract CrossChainMessenger is Ownable {
    struct InboundMessage {
        uint256 srcChainId;
        address srcContract;
        address from;
        address to;
        uint256 srcNonce;
        bytes payload;
        uint256 timestamp;
        bytes32 id;
    }

    event RelayerSet(address indexed relayer);
    event PeerSet(uint256 indexed chainId, address indexed peer);
    event MessageSent(
        bytes32 indexed id,
        uint256 indexed srcChainId,
        uint256 indexed dstChainId,
        address srcContract,
        address dstContract,
        address from,
        address to,
        uint256 nonce,
        bytes message
    );
    event MessageReceived(
        bytes32 indexed id,
        uint256 indexed srcChainId,
        uint256 indexed dstChainId,
        address srcContract,
        address from,
        address to,
        uint256 nonce,
        bytes message
    );

    address public relayer;
    mapping(uint256 => bytes32) public peers; // chainId => peer contract (encoded to bytes32)
    uint256 public nonce;
    mapping(bytes32 => bool) public processed; // messageId => processed flag
    mapping(address => InboundMessage[]) private _inbox;

    modifier onlyRelayer() {
        require(msg.sender == relayer, "NOT_RELAYER");
        _;
    }

    constructor() {
        relayer = msg.sender;
        emit RelayerSet(relayer);
    }

    function setRelayer(address _relayer) external onlyOwner {
        require(_relayer != address(0), "ZERO_ADDR");
        relayer = _relayer;
        emit RelayerSet(_relayer);
    }

    function setPeer(uint256 chainId, address peer) external onlyOwner {
        peers[chainId] = _toBytes32(peer);
        emit PeerSet(chainId, peer);
    }

    function getPeer(uint256 chainId) external view returns (address) {
        return address(uint160(uint256(peers[chainId])));
    }

    function sendMessage(
        uint256 dstChainId,
        address to,
        bytes calldata message
    ) external returns (bytes32 messageId, uint256 srcNonce) {
        bytes32 dst = peers[dstChainId];
        require(dst != bytes32(0), "PEER_NOT_SET");

        srcNonce = ++nonce;
        messageId = keccak256(
            abi.encodePacked(
                block.chainid,
                dstChainId,
                address(this),
                srcNonce,
                msg.sender,
                to,
                message
            )
        );

        emit MessageSent(
            messageId,
            block.chainid,
            dstChainId,
            address(this),
            address(uint160(uint256(dst))),
            msg.sender,
            to,
            srcNonce,
            message
        );
    }

    function receiveMessage(
        uint256 srcChainId,
        address srcContract,
        address from,
        address to,
        uint256 srcNonce,
        bytes calldata message
    ) external onlyRelayer returns (bytes32 messageId) {
        require(peers[srcChainId] == _toBytes32(srcContract), "INVALID_SRC_CONTRACT");

        messageId = keccak256(
            abi.encodePacked(
                srcChainId,
                block.chainid,
                srcContract,
                srcNonce,
                from,
                to,
                message
            )
        );
        require(!processed[messageId], "ALREADY_PROCESSED");
        processed[messageId] = true;

        InboundMessage memory m = InboundMessage({
            srcChainId: srcChainId,
            srcContract: srcContract,
            from: from,
            to: to,
            srcNonce: srcNonce,
            payload: message,
            timestamp: block.timestamp,
            id: messageId
        });

        _inbox[to].push(m);

        emit MessageReceived(
            messageId,
            srcChainId,
            block.chainid,
            srcContract,
            from,
            to,
            srcNonce,
            message
        );

        if (to.code.length > 0) {
            // best-effort callback; ignore failures
            try ICrossChainMessageReceiver(to).onCrossChainMessage(srcChainId, srcContract, from, message) {
            } catch {}
        }
    }

    function inboxLength(address user) external view returns (uint256) {
        return _inbox[user].length;
    }

    function getInboxMessage(address user, uint256 index) external view returns (InboundMessage memory) {
        require(index < _inbox[user].length, "OUT_OF_BOUNDS");
        return _inbox[user][index];
    }

    function computeMessageId(
        uint256 srcChainId,
        uint256 dstChainId,
        address srcContract,
        uint256 _nonce,
        address from,
        address to,
        bytes memory message
    ) external pure returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                srcChainId,
                dstChainId,
                srcContract,
                _nonce,
                from,
                to,
                message
            )
        );
    }

    function _toBytes32(address a) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(a)));
    }
}