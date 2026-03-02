// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// ERC20 Token with Reflection Mechanism
contract ReflectionToken {
    string public name = "Reflection Token";
    string public symbol = "RFT";
    uint8 public decimals = 18;

    uint256 private _totalSupply;
    uint256 public reflectionFee = 2; // 2% reflection

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => bool) public isExcludedFromFee;

    address public owner;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor(uint256 initialSupply) {
        owner = msg.sender;
        _totalSupply = initialSupply * 10**decimals;
        _balances[msg.sender] = _totalSupply;
        isExcludedFromFee[msg.sender] = true;
        emit Transfer(address(0), msg.sender, _totalSupply);
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 amount) public returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function allowance(address tokenOwner, address spender) public view returns (uint256) {
        return _allowances[tokenOwner][spender];
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public returns (bool) {
        require(_allowances[from][msg.sender] >= amount, "Allowance exceeded");
        _allowances[from][msg.sender] -= amount;
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(from != address(0), "Transfer from zero");
        require(to != address(0), "Transfer to zero");
        require(_balances[from] >= amount, "Insufficient balance");

        uint256 feeAmount = 0;
        if (!isExcludedFromFee[from] && !isExcludedFromFee[to]) {
            feeAmount = amount * reflectionFee / 100;
        }

        uint256 transferAmount = amount - feeAmount;

        _balances[from] -= amount;
        _balances[to] += transferAmount;

        if (feeAmount > 0) {
            _distributeReflection(feeAmount);
        }

        emit Transfer(from, to, transferAmount);
    }

    function _distributeReflection(uint256 feeAmount) internal {
        // Simplified reflection - adds to owner
        _balances[owner] += feeAmount;
    }

    function excludeFromFee(address account) external onlyOwner {
        isExcludedFromFee[account] = true;
    }

    function includeInFee(address account) external onlyOwner {
        isExcludedFromFee[account] = false;
    }

    function setReflectionFee(uint256 fee) external onlyOwner {
        require(fee <= 10, "Fee too high");
        reflectionFee = fee;
    }
}
