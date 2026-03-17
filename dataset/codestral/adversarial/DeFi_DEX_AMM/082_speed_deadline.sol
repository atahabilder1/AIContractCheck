// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract SimpleDex {
    mapping(address => uint) public balances;
    uint public tokenPrice = 1 ether; // Assume 1 ETH = 1 Token

    function deposit() public payable {
        balances[msg.sender] += msg.value / tokenPrice;
    }

    function withdraw(uint amount) public {
        require(balances[msg.sender] >= amount, "Insufficient balance");
        balances[msg.sender] -= amount;
        payable(msg.sender).transfer(amount * tokenPrice);
    }

    function swap(uint tokensSold, address tokenAddress) public {
        require(balances[tokenAddress] >= tokensSold, "Insufficient liquidity");
        balances[tokenAddress] -= tokensSold;
        balances[msg.sender] += tokensSold;
    }
}