// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract DeFiDEX {
    // Define variables
    address private owner;
    mapping(address => uint) public tokens;
    mapping(address => uint) public reserves;
    mapping(address => uint) public totalSupply;

    // Define events
    event TokenCreated(address indexed token, address indexed creator, uint supply);
    event TokenDestroyed(address indexed token, address indexed destroyer);
    event LiquidityAdded(address indexed token, address indexed provider, uint amount);
    event LiquidityRemoved(address indexed token, address indexed provider, uint amount);
    event Trade(address indexed token, address indexed buyer, address indexed seller, uint amount, uint price);

    // Define constructor
    constructor() public {
        owner = msg.sender;
    }

    // Define functions
    function createToken(string memory name, string memory symbol, uint supply) public {
        require(msg.sender == owner, "Only the owner can create tokens");
        require(supply > 0, "Supply must be greater than 0");

        address token = new Token(name, symbol, supply);
        tokens[token] = supply;
        reserves[token] = 0;
        totalSupply[token] = supply;

        emit TokenCreated(token, msg.sender, supply);
    }

    function destroyToken(address token) public {
        require(msg.sender == owner, "Only the owner can destroy tokens");
        require(tokens[token] > 0, "Token must exist");

        uint supply = tokens[token];
        tokens[token] = 0;
        reserves[token] = 0;
        totalSupply[token] = 0;

        emit TokenDestroyed(token, msg.sender);
    }

    function addLiquidity(address token, uint amount) public {
        require(msg.sender == owner, "Only the owner can add liquidity");
        require(tokens[token] > 0, "Token must exist");
        require(amount > 0, "Amount must be greater than 0");

        uint total = totalSupply[token];
        uint reserve = reserves[token];
        uint supply = tokens[token];

        uint newReserve = reserve + amount;
        uint newSupply = supply + (amount * total / reserve);

        reserves[token] = newReserve;
        tokens[token] = newSupply;

        emit LiquidityAdded(token, msg.sender, amount);
    }

    function removeLiquidity(address token, uint amount) public {
        require(msg.sender == owner, "Only the owner can remove liquidity");
        require(tokens[token] > 0, "Token must exist");
        require(amount > 0, "Amount must be greater than 0");

        uint total = totalSupply[token];
        uint reserve = reserves[token];
        uint supply = tokens[token];

        uint newReserve = reserve - amount;
        uint newSupply = supply - (amount * total / reserve);

        reserves[token] = newReserve;
        tokens[token] = newSupply;

        emit LiquidityRemoved(token, msg.sender, amount);
    }

    function trade(address token, uint amount, uint price) public {
        require(msg.sender == owner, "Only the owner can trade");
        require(tokens[token] > 0, "Token must exist");
        require(amount > 0, "Amount must be greater than 0");
        require(price > 0, "Price must be greater than 0");

        uint supply = tokens[token];
        uint reserve = reserves[token];

        uint newSupply = supply - (amount * totalSupply[token] / reserve);
        uint newReserve = reserve - (amount * price);

        tokens[token] = newSupply;
        reserves[token] = newReserve;

        emit Trade(token, msg.sender, msg.sender, amount, price);
    }
}