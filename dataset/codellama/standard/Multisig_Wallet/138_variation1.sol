// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MultiSigWallet {
    address private _owner;
    mapping(address => uint256) private _approvals;
    uint256 private _threshold;

    constructor(address owner, uint256 threshold) public {
        _owner = owner;
        _threshold = threshold;
    }

    function approve(address spender, uint256 amount) public {
        require(msg.sender == _owner, "Only the owner can approve");
        _approvals[spender] = amount;
    }

    function increaseApproval(address spender, uint256 amount) public {
        require(msg.sender == _owner, "Only the owner can increase approval");
        _approvals[spender] += amount;
    }

    function decreaseApproval(address spender, uint256 amount) public {
        require(msg.sender == _owner, "Only the owner can decrease approval");
        _approvals[spender] -= amount;
    }

    function transfer(address recipient, uint256 amount) public {
        require(_approvals[msg.sender] >= amount, "Insufficient approval");
        require(amount <= _balanceOf(msg.sender), "Insufficient balance");
        _transfer(msg.sender, recipient, amount);
    }

    function call(address target, uint256 amount, bytes calldata data) public {
        require(_approvals[msg.sender] >= amount, "Insufficient approval");
        require(amount <= _balanceOf(msg.sender), "Insufficient balance");
        _call(target, amount, data);
    }

    function changeOwner(address newOwner) public {
        require(msg.sender == _owner, "Only the owner can change owner");
        _owner = newOwner;
    }

    function _transfer(address sender, address recipient, uint256 amount) internal {
        require(sender != address(0), "Invalid sender");
        require(recipient != address(0), "Invalid recipient");
        require(amount > 0, "Invalid amount");
        _balanceOf(sender) -= amount;
        _balanceOf(recipient) += amount;
    }

    function _call(address target, uint256 amount, bytes calldata data) internal {
        require(target != address(0), "Invalid target");
        require(amount > 0, "Invalid amount");
        _balanceOf(target) += amount;
        target.functionCall(data);
    }

    function _balanceOf(address owner) internal view returns (uint256) {
        return _balances[owner];
    }
}