// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MultiRelay {
    struct Message {
        bytes32 contentHash;
        bool isSubmitted;
        uint256 submissionCount;
    }

    mapping(bytes32 => Message) public messages;

    function submitMessage(bytes32 contentHash) public {
        require(messages[contentHash].isSubmitted == false, "Message already submitted");

        messages[contentHash].contentHash = contentHash;
        messages[contentHash].isSubmitted = true;
        messages[contentHash].submissionCount++;
    }

    function isMessageValid(bytes32 contentHash) public view returns (bool) {
        return messages[contentHash].submissionCount > 1;
    }
}