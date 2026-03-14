// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MultiRelayer {
    uint256 public requiredConfirmations;
    mapping(bytes32 => uint256) public confirmations;
    mapping(bytes32 => bool) public executed;
    address[] public relayers;

    event MessageConfirmed(bytes32 indexed messageHash, address indexed relayer);
    event MessageExecuted(bytes32 indexed messageHash);

    constructor(address[] memory _relayers, uint256 _requiredConfirmations) {
        require(_relayers.length > 0, "Relayers array cannot be empty");
        require(_requiredConfirmations > 0 && _requiredConfirmations <= _relayers.length, "Invalid number of required confirmations");
        relayers = _relayers;
        requiredConfirmations = _requiredConfirmations;
    }

    modifier onlyRelayer() {
        bool isRelayer = false;
        for (uint256 i = 0; i < relayers.length; i++) {
            if (relayers[i] == msg.sender) {
                isRelayer = true;
                break;
            }
        }
        require(isRelayer, "Not a relayer");
        _;
    }

    function confirmMessage(bytes32 messageHash) public onlyRelayer {
        require(!executed[messageHash], "Message already executed");

        confirmations[messageHash]++;
        emit MessageConfirmed(messageHash, msg.sender);

        if (confirmations[messageHash] >= requiredConfirmations) {
            executeMessage(messageHash);
        }
    }

    function executeMessage(bytes32 messageHash) internal {
        executed[messageHash] = true;
        emit MessageExecuted(messageHash);
        // Here you can add the logic to execute the message
    }
}