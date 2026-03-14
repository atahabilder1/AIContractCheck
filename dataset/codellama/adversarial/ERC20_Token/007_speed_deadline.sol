// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract ERC20Token {
    string public name;
    string public symbol;
    uint public totalSupply;
    mapping(address => uint) public balances;

    constructor(string memory _name, string memory _symbol, uint _totalSupply) public {
        name = _name;
        symbol = _symbol;
        totalSupply = _totalSupply;
    }

    function transfer(address _to, uint _amount) public {
        require(msg.sender == address(this), "Only the contract owner can transfer tokens");
        require(_amount <= balances[msg.sender], "Insufficient balance");
        balances[msg.sender] -= _amount;
        balances[_to] += _amount;
    }
}