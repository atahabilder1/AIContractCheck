// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract FeeOnTransferToken {
    // ERC20 standard events
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    // Token metadata
    string private _name;
    string private _symbol;
    uint8 private constant _decimals = 18;

    // ERC20 storage
    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    // Fee configuration: 2% fee sent to treasury on each transfer
    uint256 public constant FEE_NUMERATOR = 2;
    uint256 public constant FEE_DENOMINATOR = 100;
    address public immutable treasury;

    constructor(
        string memory name_,
        string memory symbol_,
        uint256 initialSupply_, // in whole tokens (will be scaled by 10**decimals)
        address treasury_
    ) {
        require(treasury_ != address(0), "Treasury is zero");
        _name = name_;
        _symbol = symbol_;
        treasury = treasury_;

        uint256 scaledSupply = initialSupply_ * (10 ** uint256(_decimals));
        _mint(msg.sender, scaledSupply);
    }

    // ERC20 standard interface

    function name() external view returns (string memory) {
        return _name;
    }

    function symbol() external view returns (string memory) {
        return _symbol;
    }

    function decimals() external pure returns (uint8) {
        return _decimals;
    }

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function allowance(address owner, address spender) external view returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) external returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender] + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool) {
        uint256 currentAllowance = _allowances[msg.sender][spender];
        require(currentAllowance >= subtractedValue, "Decreased below zero");
        unchecked {
            _approve(msg.sender, spender, currentAllowance - subtractedValue);
        }
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 currentAllowance = _allowances[from][msg.sender];
        require(currentAllowance >= amount, "Insufficient allowance");
        unchecked {
            _approve(from, msg.sender, currentAllowance - amount);
        }
        _transfer(from, to, amount);
        return true;
    }

    // Internal logic

    function _transfer(address from, address to, uint256 amount) internal {
        require(from != address(0), "From zero");
        require(to != address(0), "To zero");

        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "Insufficient balance");

        // Calculate fee and net amount
        uint256 fee = (amount * FEE_NUMERATOR) / FEE_DENOMINATOR;
        uint256 netAmount = amount - fee;

        // Update balances
        unchecked {
            _balances[from] = fromBalance - amount;
        }

        // Credit recipient
        _balances[to] += netAmount;
        emit Transfer(from, to, netAmount);

        // Send fee to treasury if any
        if (fee > 0) {
            _balances[treasury] += fee;
            emit Transfer(from, treasury, fee);
        }
    }

    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "Owner zero");
        require(spender != address(0), "Spender zero");
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _mint(address account, uint256 amount) internal {
        require(account != address(0), "Mint to zero");
        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);
    }
}