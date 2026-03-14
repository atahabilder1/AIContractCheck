// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract BridgeRelayer {
    address public owner;
    uint256 public fee;
    mapping(bytes32 => bool) public processedMessages;

    event Deposit(address indexed sender, uint256 value, bytes32 indexed messageHash);
    event Withdraw(address indexed recipient, uint256 value);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    constructor(uint256 _fee) {
        owner = msg.sender;
        fee = _fee;
    }

    function setFee(uint256 _fee) public onlyOwner {
        fee = _fee;
    }

    function deposit(address recipient, uint256 amount) public payable {
        require(msg.value >= fee, "Insufficient fee");
        bytes32 messageHash = keccak256(abi.encodePacked(recipient, amount));
        processedMessages[messageHash] = true;
        emit Deposit(msg.sender, amount, messageHash);
    }

    function withdraw(address payable recipient, uint256 amount) public {
        bytes32 messageHash = keccak256(abi.encodePacked(recipient, amount));
        require(processedMessages[messageHash], "Message not processed");
        recipient.transfer(amount);
        emit Withdraw(recipient, amount);
    }
}