// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract WrappedNative {
    // ERC20 metadata
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;

    // ERC20 state
    uint256 private _totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    // ERC20 events
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    // Wrapped native specific events
    event Deposit(address indexed to, uint256 amount);
    event Withdrawal(address indexed from, uint256 amount);

    constructor(string memory name_, string memory symbol_) {
        name = name_;
        symbol = symbol_;
    }

    // Accept native currency and wrap to sender
    receive() external payable {
        _deposit(msg.sender, msg.value);
    }

    // ERC20: total supply
    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    // Wrap native currency to tokens for msg.sender
    function deposit() external payable {
        _deposit(msg.sender, msg.value);
    }

    // Wrap native currency to tokens for a specified address
    function depositTo(address to) external payable {
        _deposit(to, msg.value);
    }

    // Unwrap tokens to native currency for msg.sender
    function withdraw(uint256 amount) external {
        _withdraw(msg.sender, msg.sender, amount);
    }

    // Unwrap tokens to native currency for a specified recipient
    function withdrawTo(address to, uint256 amount) external {
        _withdraw(msg.sender, to, amount);
    }

    // ERC20: approve spender
    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    // ERC20: transfer tokens
    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    // ERC20: transfer tokens from another address
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (from != msg.sender && allowed != type(uint256).max) {
            require(allowed >= amount, "WN: insufficient allowance");
            unchecked {
                allowance[from][msg.sender] = allowed - amount;
            }
            emit Approval(from, msg.sender, allowance[from][msg.sender]);
        }
        _transfer(from, to, amount);
        return true;
    }

    // Internal deposit logic
    function _deposit(address to, uint256 amount) internal {
        if (amount == 0) {
            // Allow zero-value deposits as no-ops for compatibility
            return;
        }
        _totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
        emit Deposit(to, amount);
    }

    // Internal withdraw logic
    function _withdraw(address from, address to, uint256 amount) internal {
        require(balanceOf[from] >= amount, "WN: insufficient balance");
        // Effects
        unchecked {
            balanceOf[from] = balanceOf[from] - amount;
            _totalSupply = _totalSupply - amount;
        }
        emit Transfer(from, address(0), amount);
        emit Withdrawal(from, amount);
        // Interaction
        (bool ok, ) = to.call{value: amount}("");
        require(ok, "WN: native transfer failed");
    }

    // Internal transfer logic
    function _transfer(address from, address to, uint256 amount) internal {
        require(to != address(0), "WN: transfer to zero");
        require(balanceOf[from] >= amount, "WN: insufficient balance");
        unchecked {
            balanceOf[from] = balanceOf[from] - amount;
            balanceOf[to] = balanceOf[to] + amount;
        }
        emit Transfer(from, to, amount);
    }
}