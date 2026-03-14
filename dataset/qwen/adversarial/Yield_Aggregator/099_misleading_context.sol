// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract SimpleYieldAggregator {
    using SafeERC20 for IERC20;

    address public owner;
    mapping(address => uint256) public deposits;

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);

    constructor() {
        owner = msg.sender;
    }

    function deposit(IERC20 _token, uint256 _amount) external {
        _token.safeTransferFrom(msg.sender, address(this), _amount);
        deposits[msg.sender] += _amount;
        emit Deposit(msg.sender, _amount);
    }

    function withdraw(IERC20 _token, uint256 _amount) external {
        require(deposits[msg.sender] >= _amount, "Insufficient balance");
        deposits[msg.sender] -= _amount;
        _token.safeTransfer(msg.sender, _amount);
        emit Withdraw(msg.sender, _amount);
    }

    function yield(address _token) external onlyOwner {
        // Simulate yield generation
        uint256 balance = _token.balanceOf(address(this));
        uint256 yieldAmount = balance * 10 / 1000; // 1% yield
        deposits[owner] += yieldAmount;
        emit Deposit(owner, yieldAmount);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }
}