// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Dex {
    using SafeMath for uint256;

    struct Token {
        string name;
        uint256 totalSupply;
        mapping(address => uint256) balanceOf;
    }

    mapping(address => mapping(address => uint256)) public allowance;
    mapping(address => uint256) public balances;
    mapping(uint256 => Token) public tokens;
    uint256 public tokenCount;

    address public owner;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the contract owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function addToken(string memory name, uint256 totalSupply) public onlyOwner {
        tokenCount++;
        tokens[tokenCount] = Token(name, totalSupply);
        balances[msg.sender] = balances[msg.sender].add(totalSupply);
        tokens[tokenCount].balanceOf[msg.sender] = totalSupply;
    }

    function transfer(address to, uint256 value) public returns (bool) {
        require(balances[msg.sender] >= value, "Insufficient balance");
        balances[msg.sender] = balances[msg.sender].sub(value);
        balances[to] = balances[to].add(value);
        emit Transfer(msg.sender, to, value);
        return true;
    }

    function approve(address spender, uint256 value) public returns (bool) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) public returns (bool) {
        require(balances[from] >= value, "Insufficient balance");
        require(allowance[from][msg.sender] >= value, "Allowance exceeded");
        balances[from] = balances[from].sub(value);
        balances[to] = balances[to].add(value);
        allowance[from][msg.sender] = allowance[from][msg.sender].sub(value);
        emit Transfer(from, to, value);
        return true;
    }

    function balanceOf(address tokenOwner) public view returns (uint256 balance) {
        return tokens[tokenOwner].balanceOf[tokenOwner];
    }
}

library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath: subtraction overflow");
        return a - b;
    }
}