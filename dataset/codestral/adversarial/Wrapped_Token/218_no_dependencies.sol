// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract WrappedToken {
    string public name = "Wrapped Token";
    string public symbol = "WTOKEN";
    uint256 public totalSupply;
    mapping(address => uint256) public balances;
    mapping(address => mapping (address => uint256)) public allowed;

    constructor() {
        _mint(msg.sender, 1000 * (10 ** 18)); // Minting initial tokens for the contract deployer
    }

    function balanceOf(address account) external view returns (uint256) {
        return balances[account];
    }

    function transfer(address recipient, uint256 amount) external returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowed[msg.sender][spender] = amount;
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool) {
        _transfer(sender, recipient, amount);
        allowed[sender][msg.sender] -= amount;
        return true;
    }

    function allowance(address owner, address spender) public view returns (uint256) {
        return allowed[owner][spender];
    }

    function _mint(address account, uint256 amount) private {
        totalSupply += amount;
        balances[account] += amount;
    }

    function _transfer(address sender, address recipient, uint256 amount) private {
        require(balances[sender] >= amount, "Insufficient balance.");
        if (allowed[sender][msg.sender] != uint256(-1)) {
            require(allowed[sender][msg.sender] >= amount, "Allowance exceeded.");
        }
        balances[sender] -= amount;
        balances[recipient] += amount;
    }
}