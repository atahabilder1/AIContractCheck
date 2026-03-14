// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IBridge {
    function transfer(address recipient, uint256 amount) external;
    function balanceOf(address account) external view returns (uint256);
}

contract BridgeRelayer {
    address public owner;
    IBridge public bridge;

    event Transferred(address indexed recipient, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    constructor(address _bridge) {
        owner = msg.sender;
        bridge = IBridge(_bridge);
    }

    function setBridge(address _bridge) public onlyOwner {
        bridge = IBridge(_bridge);
    }

    function relayTransfer(address recipient, uint256 amount) public {
        require(bridge.balanceOf(msg.sender) >= amount, "Insufficient balance");
        bridge.transfer(recipient, amount);
        emit Transferred(recipient, amount);
    }

    function withdraw(uint256 amount) public onlyOwner {
        require(address(this).balance >= amount, "Insufficient balance");
        payable(owner).transfer(amount);
    }
}