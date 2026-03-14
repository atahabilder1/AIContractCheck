// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Dex {
    using SafeMath for uint256;

    struct Token {
        uint256 totalSupply;
        mapping(address => uint256) balanceOf;
        mapping(address => mapping(address => uint256)) allowance;
    }

    mapping(address => Token) public tokens;
    mapping(address => mapping(address => uint256)) public reserves;
    address[] public tokenList;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Mint(address indexed to, uint256 value);
    event Burn(address indexed from, uint256 value);

    function addToken(uint256 initialSupply) internal {
        Token storage token = tokens[address(new ERC20Token(initialSupply))];
        tokenList.push(address(token));
    }

    function balanceOf(address token, address account) public view returns (uint256) {
        return tokens[token].balanceOf[account];
    }

    function approve(address token, address spender, uint256 amount) public returns (bool) {
        require(amount <= tokens[token].balanceOf[msg.sender], "Insufficient balance");
        tokens[token].allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address token, address to, uint256 amount) public returns (bool) {
        require(amount <= tokens[token].balanceOf[msg.sender], "Insufficient balance");
        tokens[token].balanceOf[msg.sender] = tokens[token].balanceOf[msg.sender].sub(amount);
        tokens[token].balanceOf[to] = tokens[token].balanceOf[to].add(amount);
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address token, address from, address to, uint256 amount) public returns (bool) {
        require(amount <= tokens[token].balanceOf[from], "Insufficient balance");
        require(amount <= tokens[token].allowance[from][msg.sender], "Allowance exceeded");
        tokens[token].balanceOf[from] = tokens[token].balanceOf[from].sub(amount);
        tokens[token].balanceOf[to] = tokens[token].balanceOf[to].add(amount);
        tokens[token].allowance[from][msg.sender] = tokens[token].allowance[from][msg.sender].sub(amount);
        emit Transfer(from, to, amount);
        return true;
    }

    function mint(address token, address to, uint256 amount) public {
        tokens[token].balanceOf[to] = tokens[token].balanceOf[to].add(amount);
        tokens[token].totalSupply = tokens[token].totalSupply.add(amount);
        emit Mint(to, amount);
    }

    function burn(address token, uint256 amount) public {
        require(amount <= tokens[token].balanceOf[msg.sender], "Insufficient balance");
        tokens[token].balanceOf[msg.sender] = tokens[token].balanceOf[msg.sender].sub(amount);
        tokens[token].totalSupply = tokens[token].totalSupply.sub(amount);
        emit Burn(msg.sender, amount);
    }

    function getReserves(address token) public view returns (uint256) {
        return reserves[token][address(this)];
    }

    function swap(address tokenIn, address tokenOut, uint256 amountIn) public {
        require(amountIn <= tokens[tokenIn].balanceOf[msg.sender], "Insufficient balance");
        uint256 reserveIn = reserves[tokenIn][address(this)];
        uint256 reserveOut = reserves[tokenOut][address(this)];
        uint256 amountOut = (amountIn.mul(reserveOut)).div(reserveIn);
        require(amountOut > 0, "Insufficient liquidity");
        tokens[tokenIn].balanceOf[msg.sender] = tokens[tokenIn].balanceOf[msg.sender].sub(amountIn);
        tokens[tokenOut].balanceOf[msg.sender] = tokens[tokenOut].balanceOf[msg.sender].add(amountOut);
        reserves[tokenIn][address(this)] = reserveIn.sub(amountIn);
        reserves[tokenOut][address(this)] = reserveOut.add(amountOut);
    }
}

contract ERC20Token {
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(uint256 initialSupply) {
        balanceOf[msg.sender] = initialSupply;
        totalSupply = initialSupply;
    }

    function transfer(address to, uint256 value) public returns (bool success) {
        require(balanceOf[msg.sender] >= value, "Insufficient balance");
        balanceOf[msg.sender] -= value;
        balanceOf[to] += value;
        emit Transfer(msg.sender, to, value);
        return true;
    }

    function approve(address spender, uint256 value) public returns (bool success) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) public returns (bool success) {
        require(value <= balanceOf[from], "Insufficient balance");
        require(value <= allowance[from][msg.sender], "Allowance exceeded");
        balanceOf[from] -= value;
        balanceOf[to] += value;
        allowance[from][msg.sender] -= value;
        emit Transfer(from, to, value);
        return true;
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

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: division by zero");
        return a / b;
    }
}