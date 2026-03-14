// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";

contract MyToken is ERC20 {
    address private _owner;
    mapping (address => uint) private _balances;
    mapping (address => mapping (address => uint)) private _allowances;
    uint private _totalSupply;
    bool private _paused;
    mapping (address => bool) private _blacklisted;

    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _owner = msg.sender;
        _totalSupply = 0;
    }

    function mint(address to, uint amount) public {
        require(msg.sender == _owner, "Only the owner can mint new tokens");
        _totalSupply += amount;
        _balances[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function burn(uint amount) public {
        require(_balances[msg.sender] >= amount, "Insufficient balance");
        _totalSupply -= amount;
        _balances[msg.sender] -= amount;
        emit Transfer(msg.sender, address(0), amount);
    }

    function pause() public {
        require(msg.sender == _owner, "Only the owner can pause the contract");
        _paused = true;
    }

    function unpause() public {
        require(msg.sender == _owner, "Only the owner can unpause the contract");
        _paused = false;
    }

    function blacklist(address account) public {
        require(msg.sender == _owner, "Only the owner can blacklist accounts");
        _blacklisted[account] = true;
    }

    function isBlacklisted(address account) public view returns (bool) {
        return _blacklisted[account];
    }

    function balanceOf(address account) public view returns (uint) {
        return _balances[account];
    }

    function totalSupply() public view returns (uint) {
        return _totalSupply;
    }

    function transfer(address recipient, uint amount) public override {
        require(_balances[msg.sender] >= amount, "Insufficient balance");
        require(!_paused, "Contract is paused");
        require(!_blacklisted[msg.sender], "Sender is blacklisted");
        require(!_blacklisted[recipient], "Recipient is blacklisted");
        _balances[msg.sender] -= amount;
        _balances[recipient] += amount;
        emit Transfer(msg.sender, recipient, amount);
    }

    function transferFrom(address sender, address recipient, uint amount) public override {
        require(_allowances[sender][msg.sender] >= amount, "Insufficient allowance");
        require(_balances[sender] >= amount, "Insufficient balance");
        require(!_paused, "Contract is paused");
        require(!_blacklisted[sender], "Sender is blacklisted");
        require(!_blacklisted[recipient], "Recipient is blacklisted");
        _allowances[sender][msg.sender] -= amount;
        _balances[sender] -= amount;
        _balances[recipient] += amount;
        emit Transfer(sender, recipient, amount);
    }

    function approve(address spender, uint amount) public override {
        require(!_paused, "Contract is paused");
        require(!_blacklisted[msg.sender], "Sender is blacklisted");
        require(!_blacklisted[spender], "Spender is blacklisted");
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
    }

    function increaseAllowance(address spender, uint addedValue) public override {
        require(!_paused, "Contract is paused");
        require(!_blacklisted[msg.sender], "Sender is blacklisted");
        require(!_blacklisted[spender], "Spender is blacklisted");
        _allowances[msg.sender][spender] += addedValue;
        emit Approval(msg.sender, spender, _allowances[msg.sender][spender]);
    }

    function decreaseAllowance(address spender, uint subtractedValue) public override {
        require(!_paused, "Contract is paused");
        require(!_blacklisted[msg.sender], "Sender is blacklisted");
        require(!_blacklisted[spender], "Spender is blacklisted");
        _allowances[msg.sender][spender] -= subtractedValue;
        emit Approval(msg.sender, spender, _allowances[msg.sender][spender]);
    }

    function allowance(address owner, address spender) public view override returns (uint) {
        return _allowances[owner][spender];
    }
}