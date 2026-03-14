// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract DeFiDEX {

    address public owner;
    mapping (address => mapping (address => uint256)) public tokens;
    mapping (address => uint256) public tokenSupply;
    mapping (address => mapping (address => uint256)) public tokenReserves;

    constructor() public {
        owner = msg.sender;
    }

    function addToken(address tokenAddress, uint256 initialSupply) public {
        require(msg.sender == owner, "Only the owner can add a new token");
        require(tokenAddress != address(0), "Token address cannot be null");
        require(initialSupply > 0, "Initial supply must be greater than zero");

        tokens[tokenAddress] = initialSupply;
        tokenSupply[tokenAddress] = initialSupply;
        tokenReserves[tokenAddress][tokenAddress] = 0;
    }

    function removeToken(address tokenAddress) public {
        require(msg.sender == owner, "Only the owner can remove a token");
        require(tokenAddress != address(0), "Token address cannot be null");
        require(tokens[tokenAddress] > 0, "Token must have a positive supply");

        uint256 balance = tokens[tokenAddress];
        tokens[tokenAddress] = 0;
        tokenSupply[tokenAddress] = 0;
        tokenReserves[tokenAddress][tokenAddress] = 0;

        payable(msg.sender).transfer(balance);
    }

    function deposit(address tokenAddress, uint256 amount) public {
        require(tokenAddress != address(0), "Token address cannot be null");
        require(amount > 0, "Deposit amount must be greater than zero");

        tokens[tokenAddress] += amount;
        tokenSupply[tokenAddress] += amount;
        tokenReserves[tokenAddress][tokenAddress] += amount;
    }

    function withdraw(address tokenAddress, uint256 amount) public {
        require(tokenAddress != address(0), "Token address cannot be null");
        require(amount > 0, "Withdrawal amount must be greater than zero");
        require(tokens[tokenAddress] >= amount, "Insufficient balance");

        tokens[tokenAddress] -= amount;
        tokenSupply[tokenAddress] -= amount;
        tokenReserves[tokenAddress][tokenAddress] -= amount;

        payable(msg.sender).transfer(amount);
    }

    function getTokenSupply(address tokenAddress) public view returns (uint256) {
        require(tokenAddress != address(0), "Token address cannot be null");
        return tokenSupply[tokenAddress];
    }

    function getTokenReserves(address tokenAddress) public view returns (uint256) {
        require(tokenAddress != address(0), "Token address cannot be null");
        return tokenReserves[tokenAddress][tokenAddress];
    }

    function getTokenBalance(address tokenAddress) public view returns (uint256) {
        require(tokenAddress != address(0), "Token address cannot be null");
        return tokens[tokenAddress];
    }
}