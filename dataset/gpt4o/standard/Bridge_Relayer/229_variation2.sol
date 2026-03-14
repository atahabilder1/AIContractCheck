// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract BridgeRelayer {
    struct Message {
        uint256 id;
        address payable sender;
        address recipient;
        uint256 amount;
        uint256 fee;
        bool processed;
    }

    Message[] public messages;
    mapping(uint256 => address) public highestBidder;
    mapping(uint256 => uint256) public highestBid;

    event MessageSubmitted(uint256 indexed id, address indexed sender, address indexed recipient, uint256 amount, uint256 fee);
    event BidPlaced(uint256 indexed messageId, address indexed bidder, uint256 bidAmount);
    event MessageProcessed(uint256 indexed id, address indexed relayer);

    function submitMessage(address recipient, uint256 amount) external payable {
        require(msg.value > 0, "Fee must be greater than zero");
        uint256 messageId = messages.length;
        messages.push(Message({
            id: messageId,
            sender: payable(msg.sender),
            recipient: recipient,
            amount: amount,
            fee: msg.value,
            processed: false
        }));
        emit MessageSubmitted(messageId, msg.sender, recipient, amount, msg.value);
    }

    function placeBid(uint256 messageId) external payable {
        require(messageId < messages.length, "Invalid message ID");
        require(!messages[messageId].processed, "Message already processed");
        require(msg.value > highestBid[messageId], "Bid must be higher than current highest bid");

        if (highestBid[messageId] > 0) {
            payable(highestBidder[messageId]).transfer(highestBid[messageId]);
        }

        highestBid[messageId] = msg.value;
        highestBidder[messageId] = msg.sender;
        emit BidPlaced(messageId, msg.sender, msg.value);
    }

    function processMessage(uint256 messageId) external {
        require(messageId < messages.length, "Invalid message ID");
        require(!messages[messageId].processed, "Message already processed");
        require(highestBidder[messageId] == msg.sender, "Only highest bidder can process");

        Message storage message = messages[messageId];
        message.processed = true;
        message.sender.transfer(message.fee);
        payable(msg.sender).transfer(highestBid[messageId]);
        emit MessageProcessed(messageId, msg.sender);
    }

    function getMessage(uint256 messageId) external view returns (address, address, uint256, uint256, bool) {
        require(messageId < messages.length, "Invalid message ID");
        Message storage message = messages[messageId];
        return (message.sender, message.recipient, message.amount, message.fee, message.processed);
    }
}