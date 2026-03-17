// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CrossChainBridge {
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the contract owner can call this function");
        _;
    }

    struct TransferRequest {
        address recipient;
        uint256 amount;
        bytes32 data;
    }

    event TransferInitiated(address indexed fromChain, address indexed recipient, uint256 amount, bytes32 data);

    mapping(bytes32 => TransferRequest) public transferRequests;

    function lockTokens(uint256 _amount, bytes memory _data) public returns (bytes32) {
        bytes32 requestId = keccak256(abi.encodePacked(_msgSender(), _blockNumber(), _amount, _data));
        transferRequests[requestId] = TransferRequest(msg.sender, _amount, keccak256(_data));
        emit TransferInitiated(msg.sender, msg.sender, _amount, keccak256(_data));
        return requestId;
    }

    function releaseTokens(bytes32 _requestId) public onlyOwner {
        TransferRequest memory transfer = transferRequests[_requestId];
        delete transferRequests[_requestId];
        (bool success, ) = transfer.recipient.call{value: transfer.amount}(abi.encodeWithSignature("receiveTokens(bytes32)", _requestId));
        require(success, "Transfer failed");
    }
}