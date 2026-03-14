// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CrossChainBridge {
    address public owner;
    mapping(bytes32 => bool) public processedMessages;

    event Deposit(bytes32 indexed messageHash, address indexed from, uint256 value);
    event Withdrawal(bytes32 indexed messageHash, address indexed to, uint256 value);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function deposit(address to, uint256 value) public payable {
        require(msg.value == value, "Value must be equal to the deposited amount");
        bytes32 messageHash = keccak256(abi.encodePacked(to, value));
        processedMessages[messageHash] = true;
        emit Deposit(messageHash, to, value);
    }

    function withdraw(address to, uint256 value) public {
        bytes32 messageHash = keccak256(abi.encodePacked(to, value));
        require(processedMessages[messageHash], "Message not processed");
        require(address(this).balance >= value, "Contract does not have enough funds");

        (bool success, ) = to.call{value: value}("");
        require(success, "Transfer failed");

        emit Withdrawal(messageHash, to, value);
    }

    function setOwner(address newOwner) public onlyOwner {
        owner = newOwner;
    }
}