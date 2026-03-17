// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IMessage {
    uint256 nonce;
    address sender;
    bytes data;
}

contract CrossChainMessagingProtocol {
    mapping(address => uint256) public sourceChains;
    uint256 public gasLimit;

    constructor(uint256 _gasLimit) {
        gasLimit = _gasLimit;
    }

    function verifySourceChain(address _sourceChain) public view returns (bool) {
        return sourceChains[_sourceChain] > 0;
    }

    function addSourceChain(address _sourceChain, uint256 _weight) public {
        sourceChains[_sourceChain] = _weight;
    }

    function removeSourceChain(address _sourceChain) public {
        delete sourceChains[_sourceChain];
    }

    function receiveMessage(IMessage memory message, bytes memory proof) external {
        require(verifySourceChain(message.sender), "Invalid source chain");
        uint256 expectedNonce = sourceChains[message.sender]++;
        require(message.nonce == expectedNonce, "Out of order message");

        // Verify the proof of message origin from the source chain

        // Execute the message with gas limit
        assembly {
            let result := delegatecall(gas(), address(this), add(message.data, 0x20), mload(message.data), 0, gasLimit())
            require(result, "Message execution failed")
        }
    }
}