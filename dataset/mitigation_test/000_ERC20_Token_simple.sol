// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract BasicToken is ERC20, Ownable, ReentrancyGuard {
    uint256 public constant MAX_SUPPLY = 1000000000 * 10**18; // 1 billion tokens

    event TokensMinted(address indexed to, uint256 amount);
    event TokensBurned(address indexed from, uint256 amount);

    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply
    ) ERC20(name, symbol) {
        require(bytes(name).length > 0, "Name cannot be empty");
        require(bytes(symbol).length > 0, "Symbol cannot be empty");
        require(initialSupply <= MAX_SUPPLY, "Initial supply exceeds max supply");
        
        if (initialSupply > 0) {
            _mint(msg.sender, initialSupply);
        }
    }

    modifier validAddress(address addr) {
        require(addr != address(0), "Invalid address: zero address");
        _;
    }

    modifier validAmount(uint256 amount) {
        require(amount > 0, "Amount must be greater than zero");
        _;
    }

    function mint(address to, uint256 amount) 
        external 
        onlyOwner 
        nonReentrant 
        validAddress(to) 
        validAmount(amount) 
    {
        require(totalSupply() + amount <= MAX_SUPPLY, "Mint would exceed max supply");
        
        _mint(to, amount);
        emit TokensMinted(to, amount);
    }

    function burn(uint256 amount) 
        external 
        nonReentrant 
        validAmount(amount) 
    {
        require(balanceOf(msg.sender) >= amount, "Insufficient balance to burn");
        
        _burn(msg.sender, amount);
        emit TokensBurned(msg.sender, amount);
    }

    function burnFrom(address from, uint256 amount) 
        external 
        nonReentrant 
        validAddress(from) 
        validAmount(amount) 
    {
        require(balanceOf(from) >= amount, "Insufficient balance to burn");
        
        uint256 currentAllowance = allowance(from, msg.sender);
        require(currentAllowance >= amount, "Burn amount exceeds allowance");
        
        _spendAllowance(from, msg.sender, amount);
        _burn(from, amount);
        emit TokensBurned(from, amount);
    }

    function transfer(address to, uint256 amount) 
        public 
        override 
        validAddress(to) 
        validAmount(amount) 
        returns (bool) 
    {
        return super.transfer(to, amount);
    }

    function transferFrom(address from, address to, uint256 amount) 
        public 
        override 
        validAddress(from) 
        validAddress(to) 
        validAmount(amount) 
        returns (bool) 
    {
        return super.transferFrom(from, to, amount);
    }

    function approve(address spender, uint256 amount) 
        public 
        override 
        validAddress(spender) 
        returns (bool) 
    {
        return super.approve(spender, amount);
    }
}