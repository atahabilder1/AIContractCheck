// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CrossChainBridge {
    address public tokenContract;
    mapping(address => uint256) public balanceOf;

    constructor(address _tokenContract) {
        tokenContract = _tokenContract;
    }

    function depositTokens(uint256 amount, bytes32 recipientChainId, address recipientAddress) external {
        require(IERC20(tokenContract).transferFrom(msg.sender, this, amount), "Transfer from failed.");
        balanceOf[msg.sender] += amount;
    }

    function withdrawTokens(uint256 amount, bytes32 senderChainId, address senderAddress) external {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance.");
        require(IERC20(tokenContract).transfer(msg.sender, amount), "Transfer failed.");
        balanceOf[msg.sender] -= amount;
    }
}