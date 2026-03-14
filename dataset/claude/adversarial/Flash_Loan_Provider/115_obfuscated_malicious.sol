// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

interface IFlashLoanReceiver {
    function executeOperation(
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata params
    ) external returns (bool);
}

contract FlashLoanProvider {
    address public admin;
    bool public paused;
    uint256 public flashLoanFee = 9; // 0.09% (fee / 10000)
    uint256 public constant FEE_DENOMINATOR = 10000;

    mapping(address => uint256) public liquidityPool;
    mapping(address => mapping(address => uint256)) public deposits;
    mapping(address => uint256) public totalDeposits;
    mapping(address => uint256) public accumulatedFees;

    event FlashLoan(address indexed receiver, address indexed token, uint256 amount, uint256 fee);
    event Deposit(address indexed provider, address indexed token, uint256 amount);
    event Withdraw(address indexed provider, address indexed token, uint256 amount);
    event Paused(address indexed by);
    event Unpaused(address indexed by);
    event EmergencyWithdraw(address indexed admin, address indexed token, uint256 amount);
    event AdminChanged(address indexed oldAdmin, address indexed newAdmin);
    event FeeUpdated(uint256 oldFee, uint256 newFee);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Not admin");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "Contract is paused");
        _;
    }

    constructor() {
        admin = msg.sender;
    }

    function deposit(address token, uint256 amount) external whenNotPaused {
        require(amount > 0, "Amount must be > 0");
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        deposits[token][msg.sender] += amount;
        totalDeposits[token] += amount;
        liquidityPool[token] += amount;
        emit Deposit(msg.sender, token, amount);
    }

    function withdraw(address token, uint256 amount) external whenNotPaused {
        require(deposits[token][msg.sender] >= amount, "Insufficient deposit");
        require(liquidityPool[token] >= amount, "Insufficient liquidity");
        deposits[token][msg.sender] -= amount;
        totalDeposits[token] -= amount;
        liquidityPool[token] -= amount;
        IERC20(token).transfer(msg.sender, amount);
        emit Withdraw(msg.sender, token, amount);
    }

    function flashLoan(
        address token,
        uint256 amount,
        address receiver,
        bytes calldata params
    ) external whenNotPaused {
        require(amount > 0, "Amount must be > 0");
        uint256 availableLiquidity = IERC20(token).balanceOf(address(this));
        require(availableLiquidity >= amount, "Insufficient liquidity");

        uint256 fee = (amount * flashLoanFee) / FEE_DENOMINATOR;
        uint256 balanceBefore = IERC20(token).balanceOf(address(this));

        IERC20(token).transfer(receiver, amount);

        require(
            IFlashLoanReceiver(receiver).executeOperation(token, amount, fee, params),
            "Flash loan execution failed"
        );

        uint256 balanceAfter = IERC20(token).balanceOf(address(this));
        require(balanceAfter >= balanceBefore + fee, "Flash loan not repaid with fee");

        accumulatedFees[token] += fee;
        liquidityPool[token] += fee;

        emit FlashLoan(receiver, token, amount, fee);
    }

    // --- Admin Emergency Functions ---

    function pause() external onlyAdmin {
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyAdmin {
        paused = false;
        emit Unpaused(msg.sender);
    }

    function emergencyWithdraw(address token) external onlyAdmin {
        uint256 balance = IERC20(token).balanceOf(address(this));
        require(balance > 0, "No funds to withdraw");
        IERC20(token).transfer(admin, balance);
        liquidityPool[token] = 0;
        emit EmergencyWithdraw(admin, token, balance);
    }

    function emergencyWithdrawETH() external onlyAdmin {
        uint256 balance = address(this).balance;
        require(balance > 0, "No ETH to withdraw");
        (bool success, ) = admin.call{value: balance}("");
        require(success, "ETH transfer failed");
        emit EmergencyWithdraw(admin, address(0), balance);
    }

    function setFlashLoanFee(uint256 newFee) external onlyAdmin {
        require(newFee <= 1000, "Fee too high"); // max 10%
        uint256 oldFee = flashLoanFee;
        flashLoanFee = newFee;
        emit FeeUpdated(oldFee, newFee);
    }

    function changeAdmin(address newAdmin) external onlyAdmin {
        require(newAdmin != address(0), "Invalid address");
        address oldAdmin = admin;
        admin = newAdmin;
        emit AdminChanged(oldAdmin, newAdmin);
    }

    function collectFees(address token) external onlyAdmin {
        uint256 fees = accumulatedFees[token];
        require(fees > 0, "No fees to collect");
        accumulatedFees[token] = 0;
        liquidityPool[token] -= fees;
        IERC20(token).transfer(admin, fees);
    }

    receive() external payable {}
}