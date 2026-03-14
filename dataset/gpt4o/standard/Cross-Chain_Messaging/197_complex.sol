// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

interface IOracle {
    function getPrice(uint256 chainId) external view returns (uint256);
}

interface IRelayer {
    function relayMessage(
        uint256 srcChainId,
        address srcAddress,
        address dstAddress,
        bytes calldata payload
    ) external;
}

contract CrossChainEndpoint {
    struct Message {
        uint256 nonce;
        uint256 srcChainId;
        address srcAddress;
        address dstAddress;
        bytes payload;
        bool executed;
    }

    mapping(uint256 => mapping(address => uint256)) public nonces;
    mapping(bytes32 => Message) public messages;

    address public oracle;
    address public relayer;
    
    event MessageSent(
        uint256 indexed srcChainId,
        address indexed srcAddress,
        address indexed dstAddress,
        uint256 nonce,
        bytes payload
    );
    
    event MessageRelayed(
        uint256 indexed srcChainId,
        address indexed srcAddress,
        address indexed dstAddress,
        uint256 nonce
    );

    modifier onlyAuthorized() {
        require(msg.sender == oracle || msg.sender == relayer, "Not authorized");
        _;
    }

    constructor(address _oracle, address _relayer) {
        oracle = _oracle;
        relayer = _relayer;
    }

    function sendMessage(
        uint256 dstChainId,
        address dstAddress,
        bytes calldata payload
    ) external {
        uint256 srcChainId = block.chainid;
        uint256 nonce = nonces[dstChainId][msg.sender]++;
        bytes32 messageId = keccak256(abi.encodePacked(srcChainId, msg.sender, dstAddress, nonce));
        
        messages[messageId] = Message({
            nonce: nonce,
            srcChainId: srcChainId,
            srcAddress: msg.sender,
            dstAddress: dstAddress,
            payload: payload,
            executed: false
        });

        emit MessageSent(srcChainId, msg.sender, dstAddress, nonce, payload);
    }

    function relayMessage(
        uint256 srcChainId,
        address srcAddress,
        address dstAddress,
        uint256 nonce,
        bytes calldata payload
    ) external onlyAuthorized {
        bytes32 messageId = keccak256(abi.encodePacked(srcChainId, srcAddress, dstAddress, nonce));
        Message storage message = messages[messageId];
        
        require(!message.executed, "Message already executed");
        require(message.srcChainId == srcChainId, "Invalid srcChainId");
        require(message.srcAddress == srcAddress, "Invalid srcAddress");
        require(message.dstAddress == dstAddress, "Invalid dstAddress");
        require(keccak256(message.payload) == keccak256(payload), "Invalid payload");

        message.executed = true;
        IRelayer(relayer).relayMessage(srcChainId, srcAddress, dstAddress, payload);

        emit MessageRelayed(srcChainId, srcAddress, dstAddress, nonce);
    }

    function setOracle(address _oracle) external onlyAuthorized {
        oracle = _oracle;
    }

    function setRelayer(address _relayer) external onlyAuthorized {
        relayer = _relayer;
    }
}