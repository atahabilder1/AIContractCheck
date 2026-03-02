// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// ERC20 Token with Anti-Whale Mechanism
contract AntiWhaleToken {
    string public name = "Anti Whale Token";
    string public symbol = "AWT";
    uint8 public decimals = 18;
    uint256 public totalSupply;

    uint256 public maxTransferAmount;
    uint256 public maxWalletBalance;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    mapping(address => bool) public isExempt;

    address public owner;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor(uint256 initialSupply) {
        owner = msg.sender;
        totalSupply = initialSupply * 10**decimals;
        balanceOf[msg.sender] = totalSupply;

        maxTransferAmount = totalSupply / 100; // 1% max transfer
        maxWalletBalance = totalSupply / 50;   // 2% max wallet

        isExempt[msg.sender] = true;
        emit Transfer(address(0), msg.sender, totalSupply);
    }

    function transfer(address to, uint256 amount) public returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public returns (bool) {
        require(allowance[from][msg.sender] >= amount, "Allowance exceeded");
        allowance[from][msg.sender] -= amount;
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(from != address(0), "Transfer from zero");
        require(to != address(0), "Transfer to zero");
        require(balanceOf[from] >= amount, "Insufficient balance");

        if (!isExempt[from] && !isExempt[to]) {
            require(amount <= maxTransferAmount, "Transfer exceeds max");
            require(balanceOf[to] + amount <= maxWalletBalance, "Wallet exceeds max");
        }

        balanceOf[from] -= amount;
        balanceOf[to] += amount;

        emit Transfer(from, to, amount);
    }

    function setMaxTransferAmount(uint256 amount) external onlyOwner {
        maxTransferAmount = amount;
    }

    function setMaxWalletBalance(uint256 amount) external onlyOwner {
        maxWalletBalance = amount;
    }

    function setExempt(address account, bool exempt) external onlyOwner {
        isExempt[account] = exempt;
    }
}
