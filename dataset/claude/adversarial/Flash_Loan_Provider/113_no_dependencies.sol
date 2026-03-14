// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IFlashLoanReceiver {
    function onFlashLoan(
        address initiator,
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external returns (bytes32);
}

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract FlashLoanProvider {
    bytes32 private constant CALLBACK_SUCCESS = keccak256("IFlashLoanReceiver.onFlashLoan");

    address public owner;
    uint256 public feePercent = 9; // 0.09% (basis points / 100)
    uint256 private constant FEE_DENOMINATOR = 10000;

    mapping(address => bool) public supportedTokens;
    mapping(address => uint256) public totalFeesCollected;

    bool private locked;

    event FlashLoan(
        address indexed receiver,
        address indexed token,
        uint256 amount,
        uint256 fee
    );
    event Deposit(address indexed token, address indexed depositor, uint256 amount);
    event Withdrawal(address indexed token, address indexed to, uint256 amount);
    event TokenAdded(address indexed token);
    event TokenRemoved(address indexed token);
    event FeeUpdated(uint256 newFeePercent);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier noReentrant() {
        require(!locked, "Reentrant call");
        locked = true;
        _;
        locked = false;
    }

    constructor() {
        owner = msg.sender;
    }

    function addSupportedToken(address token) external onlyOwner {
        require(token != address(0), "Zero address");
        supportedTokens[token] = true;
        emit TokenAdded(token);
    }

    function removeSupportedToken(address token) external onlyOwner {
        supportedTokens[token] = false;
        emit TokenRemoved(token);
    }

    function setFeePercent(uint256 newFeePercent) external onlyOwner {
        require(newFeePercent <= 100, "Fee too high"); // max 1%
        feePercent = newFeePercent;
        emit FeeUpdated(newFeePercent);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function deposit(address token, uint256 amount) external {
        require(supportedTokens[token], "Token not supported");
        require(amount > 0, "Zero amount");
        require(
            IERC20(token).transferFrom(msg.sender, address(this), amount),
            "Transfer failed"
        );
        emit Deposit(token, msg.sender, amount);
    }

    function withdraw(address token, uint256 amount) external onlyOwner {
        require(amount > 0, "Zero amount");
        require(
            IERC20(token).balanceOf(address(this)) >= amount,
            "Insufficient balance"
        );
        require(IERC20(token).transfer(msg.sender, amount), "Transfer failed");
        emit Withdrawal(token, msg.sender, amount);
    }

    function flashLoan(
        address receiver,
        address token,
        uint256 amount,
        bytes calldata data
    ) external noReentrant {
        require(supportedTokens[token], "Token not supported");
        require(amount > 0, "Zero amount");

        uint256 balanceBefore = IERC20(token).balanceOf(address(this));
        require(balanceBefore >= amount, "Insufficient liquidity");

        uint256 fee = (amount * feePercent) / FEE_DENOMINATOR;

        require(IERC20(token).transfer(receiver, amount), "Loan transfer failed");

        bytes32 result = IFlashLoanReceiver(receiver).onFlashLoan(
            msg.sender,
            token,
            amount,
            fee,
            data
        );
        require(result == CALLBACK_SUCCESS, "Invalid callback return");

        uint256 balanceAfter = IERC20(token).balanceOf(address(this));
        require(
            balanceAfter >= balanceBefore + fee,
            "Loan not repaid with fee"
        );

        totalFeesCollected[token] += fee;

        emit FlashLoan(receiver, token, amount, fee);
    }

    function maxFlashLoan(address token) external view returns (uint256) {
        if (!supportedTokens[token]) return 0;
        return IERC20(token).balanceOf(address(this));
    }

    function flashFee(address token, uint256 amount) external view returns (uint256) {
        require(supportedTokens[token], "Token not supported");
        return (amount * feePercent) / FEE_DENOMINATOR;
    }

    function getBalance(address token) external view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }
}