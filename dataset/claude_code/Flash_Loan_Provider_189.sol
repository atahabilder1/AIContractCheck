// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Basic Flash Loan Provider
contract FlashLoanProvider {
    address public owner;
    uint256 public fee = 9; // 0.09% fee (9 basis points)
    uint256 public constant FEE_DENOMINATOR = 10000;

    mapping(address => uint256) public reserves;

    event FlashLoan(address indexed borrower, address indexed token, uint256 amount, uint256 fee);
    event Deposit(address indexed token, uint256 amount);
    event Withdraw(address indexed token, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function deposit(address token, uint256 amount) external {
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        reserves[token] += amount;
        emit Deposit(token, amount);
    }

    function withdraw(address token, uint256 amount) external onlyOwner {
        require(reserves[token] >= amount, "Insufficient reserves");
        reserves[token] -= amount;
        IERC20(token).transfer(owner, amount);
        emit Withdraw(token, amount);
    }

    function flashLoan(
        address token,
        uint256 amount,
        address borrower,
        bytes calldata data
    ) external {
        uint256 balanceBefore = IERC20(token).balanceOf(address(this));
        require(balanceBefore >= amount, "Insufficient liquidity");

        uint256 feeAmount = amount * fee / FEE_DENOMINATOR;

        // Transfer tokens to borrower
        IERC20(token).transfer(borrower, amount);

        // Execute callback
        IFlashLoanReceiver(borrower).executeOperation(token, amount, feeAmount, data);

        // Check repayment
        uint256 balanceAfter = IERC20(token).balanceOf(address(this));
        require(balanceAfter >= balanceBefore + feeAmount, "Flash loan not repaid");

        reserves[token] += feeAmount;

        emit FlashLoan(borrower, token, amount, feeAmount);
    }

    function setFee(uint256 _fee) external onlyOwner {
        require(_fee <= 100, "Fee too high"); // Max 1%
        fee = _fee;
    }

    function getMaxFlashLoan(address token) external view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }

    function flashFee(address, uint256 amount) external view returns (uint256) {
        return amount * fee / FEE_DENOMINATOR;
    }
}

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

interface IFlashLoanReceiver {
    function executeOperation(
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external;
}
