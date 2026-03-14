// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract BridgeRelayer {
    address public owner;
    uint256 public fee;
    mapping(bytes32 => bool) public processedMessages;

    event Deposit(bytes32 indexed messageHash, address indexed sender, uint256 amount);
    event Withdraw(bytes32 indexed messageHash, address indexed receiver, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    constructor(uint256 _fee) {
        owner = msg.sender;
        fee = _fee;
    }

    function setOwner(address newOwner) public onlyOwner {
        owner = newOwner;
    }

    function setFee(uint256 newFee) public onlyOwner {
        fee = newFee;
    }

    function deposit(address receiver, uint256 amount) public payable {
        require(msg.value >= fee, "Insufficient fee");
        bytes32 messageHash = keccak256(abi.encodePacked(receiver, amount));
        processedMessages[messageHash] = true;
        emit Deposit(messageHash, receiver, amount);
    }

    function withdraw(address sender, address receiver, uint256 amount) public {
        bytes32 messageHash = keccak256(abi.encodePacked(receiver, amount));
        require(processedMessages[messageHash], "Message not processed");
        require(address(this).balance >= amount, "Insufficient balance");
        (bool success, ) = receiver.call{value: amount}("");
        require(success, "Transfer failed");
        emit Withdraw(messageHash, receiver, amount);
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }
}