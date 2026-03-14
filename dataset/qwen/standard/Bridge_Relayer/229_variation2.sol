// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract BridgeRelayer {
    struct Message {
        address sender;
        address recipient;
        uint256 amount;
        uint256 fee;
        bool processed;
    }

    mapping(uint256 => Message) public messages;
    uint256 public messageCount;
    mapping(uint256 => address) public highestBidder;
    mapping(uint256 => uint256) public highestBid;

    event MessageAdded(uint256 indexed messageId, address sender, address recipient, uint256 amount, uint256 fee);
    event BidPlaced(uint256 indexed messageId, address indexed relayer, uint256 bid);
    event MessageProcessed(uint256 indexed messageId, address indexed relayer);

    function addMessage(address _recipient, uint256 _amount, uint256 _fee) external {
        messages[messageCount] = Message(msg.sender, _recipient, _amount, _fee, false);
        emit MessageAdded(messageCount, msg.sender, _recipient, _amount, _fee);
        messageCount++;
    }

    function placeBid(uint256 _messageId) external payable {
        require(!messages[_messageId].processed, "Message already processed");
        require(msg.value > highestBid[_messageId], "Bid must be higher than the current highest bid");
        
        if (highestBid[_messageId] > 0) {
            payable(highestBidder[_messageId]).transfer(highestBid[_messageId]);
        }

        highestBidder[_messageId] = msg.sender;
        highestBid[_messageId] = msg.value;
        emit BidPlaced(_messageId, msg.sender, msg.value);
    }

    function processMessage(uint256 _messageId) external {
        require(msg.sender == highestBidder[_messageId], "Only the highest bidder can process the message");
        require(!messages[_messageId].processed, "Message already processed");

        messages[_messageId].processed = true;
        payable(messages[_messageId].recipient).transfer(messages[_messageId].amount);
        emit MessageProcessed(_messageId, msg.sender);
    }

    function withdrawFees() external {
        uint256 balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }
}