// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Token {
    // Public variables
    string public name;
    string public symbol;
    uint public totalSupply;
    mapping(address => uint) public balances;

    // Constructor
    constructor(string memory _name, string memory _symbol, uint _totalSupply) public {
        name = _name;
        symbol = _symbol;
        totalSupply = _totalSupply;
    }

    // Transfer function
    function transfer(address to, uint amount) public returns (bool) {
        require(balances[msg.sender] >= amount, "Insufficient balance");
        balances[msg.sender] -= amount;
        balances[to] += amount;
        return true;
    }

    // Approve function
    function approve(address spender, uint amount) public returns (bool) {
        require(balances[msg.sender] >= amount, "Insufficient balance");
        balances[spender] += amount;
        return true;
    }

    // TransferFrom function
    function transferFrom(address from, address to, uint amount) public returns (bool) {
        require(balances[from] >= amount, "Insufficient balance");
        balances[from] -= amount;
        balances[to] += amount;
        return true;
    }

    // Mint function
    function mint(address to, uint amount) public returns (bool) {
        require(totalSupply + amount <= MAX_SUPPLY, "Max supply exceeded");
        totalSupply += amount;
        balances[to] += amount;
        return true;
    }

    // Burn function
    function burn(address from, uint amount) public returns (bool) {
        require(balances[from] >= amount, "Insufficient balance");
        balances[from] -= amount;
        totalSupply -= amount;
        return true;
    }
}