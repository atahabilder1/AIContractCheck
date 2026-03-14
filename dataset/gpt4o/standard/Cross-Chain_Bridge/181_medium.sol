// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CrossChainBridge {
    address public owner;
    mapping(address => bool) public whitelistRelayers;
    mapping(bytes32 => bool) public processedMessages;
    mapping(address => uint256) public nonces;

    event MessageReceived(address indexed from, uint256 nonce, bytes32 messageHash);
    event MessageProcessed(bytes32 indexed messageHash);
    event RelayerAdded(address indexed relayer);
    event RelayerRemoved(address indexed relayer);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }

    modifier onlyWhitelistedRelayer() {
        require(whitelistRelayers[msg.sender], "Relayer not whitelisted");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function addRelayer(address _relayer) external onlyOwner {
        whitelistRelayers[_relayer] = true;
        emit RelayerAdded(_relayer);
    }

    function removeRelayer(address _relayer) external onlyOwner {
        whitelistRelayers[_relayer] = false;
        emit RelayerRemoved(_relayer);
    }

    function receiveMessage(
        address _from,
        uint256 _nonce,
        bytes32 _messageHash,
        bytes calldata _signature
    ) external onlyWhitelistedRelayer {
        require(!processedMessages[_messageHash], "Message already processed");
        require(_nonce == nonces[_from] + 1, "Invalid nonce");

        bytes32 ethSignedMessageHash = getEthSignedMessageHash(_from, _nonce, _messageHash);
        require(recoverSigner(ethSignedMessageHash, _signature) == _from, "Invalid signature");

        nonces[_from] = _nonce;
        processedMessages[_messageHash] = true;

        emit MessageReceived(_from, _nonce, _messageHash);
        emit MessageProcessed(_messageHash);
    }

    function getEthSignedMessageHash(
        address _from,
        uint256 _nonce,
        bytes32 _messageHash
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(_from, _nonce, _messageHash));
    }

    function recoverSigner(bytes32 _ethSignedMessageHash, bytes memory _signature)
        internal
        pure
        returns (address)
    {
        (bytes32 r, bytes32 s, uint8 v) = splitSignature(_signature);
        return ecrecover(_ethSignedMessageHash, v, r, s);
    }

    function splitSignature(bytes memory _sig)
        internal
        pure
        returns (bytes32 r, bytes32 s, uint8 v)
    {
        require(_sig.length == 65, "Invalid signature length");

        assembly {
            r := mload(add(_sig, 32))
            s := mload(add(_sig, 64))
            v := byte(0, mload(add(_sig, 96)))
        }
    }
}