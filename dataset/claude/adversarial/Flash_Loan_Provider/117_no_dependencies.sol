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
    bytes32 private constant CALLBACK_SUCCESS = keccak256("FlashLoanReceiver.onFlashLoan");

    address public owner;
    uint256 public feePercentage; // in basis points (e.g., 9 = 0.09%)
    uint256 public constant MAX_FEE = 1000; // 10% max fee

    mapping(address => bool) public supportedTokens;
    mapping(address => uint256) public collectedFees;

    bool private _locked;

    event FlashLoan(
        address indexed receiver,
        address indexed token,
        uint256 amount,
        uint256 fee
    );
    event TokenAdded(address indexed token);
    event TokenRemoved(address indexed token);
    event FeeUpdated(uint256 oldFee, uint256 newFee);
    event FeesWithdrawn(address indexed token, uint256 amount);
    event LiquidityDeposited(address indexed token, uint256 amount);
    event LiquidityWithdrawn(address indexed token, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier noReentrant() {
        require(!_locked, "Reentrant call");
        _locked = true;
        _;
        _locked = false;
    }

    constructor(uint256 _feePercentage) {
        require(_feePercentage <= MAX_FEE, "Fee too high");
        owner = msg.sender;
        feePercentage = _feePercentage;
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

    function setFeePercentage(uint256 _feePercentage) external onlyOwner {
        require(_feePercentage <= MAX_FEE, "Fee too high");
        uint256 oldFee = feePercentage;
        feePercentage = _feePercentage;
        emit FeeUpdated(oldFee, _feePercentage);
    }

    function depositLiquidity(address token, uint256 amount) external onlyOwner {
        require(supportedTokens[token], "Token not supported");
        require(amount > 0, "Zero amount");
        bool success = IERC20(token).transferFrom(msg.sender, address(this), amount);
        require(success, "Transfer failed");
        emit LiquidityDeposited(token, amount);
    }

    function withdrawLiquidity(address token, uint256 amount) external onlyOwner {
        require(amount > 0, "Zero amount");
        uint256 available = IERC20(token).balanceOf(address(this)) - collectedFees[token];
        require(amount <= available, "Insufficient liquidity");
        bool success = IERC20(token).transfer(msg.sender, amount);
        require(success, "Transfer failed");
        emit LiquidityWithdrawn(token, amount);
    }

    function flashLoan(
        address receiverAddress,
        address token,
        uint256 amount,
        bytes calldata data
    ) external noReentrant {
        require(supportedTokens[token], "Token not supported");
        require(amount > 0, "Zero amount");

        uint256 balanceBefore = IERC20(token).balanceOf(address(this));
        require(balanceBefore >= amount, "Insufficient pool balance");

        uint256 fee = (amount * feePercentage) / 10000;

        bool sent = IERC20(token).transfer(receiverAddress, amount);
        require(sent, "Transfer to receiver failed");

        bytes32 result = IFlashLoanReceiver(receiverAddress).onFlashLoan(
            msg.sender,
            token,
            amount,
            fee,
            data
        );
        require(result == CALLBACK_SUCCESS, "Invalid callback return");

        uint256 balanceAfter = IERC20(token).balanceOf(address(this));
        require(balanceAfter >= balanceBefore + fee, "Loan not repaid with fee");

        collectedFees[token] += fee;

        emit FlashLoan(receiverAddress, token, amount, fee);
    }

    function withdrawFees(address token) external onlyOwner {
        uint256 fees = collectedFees[token];
        require(fees > 0, "No fees to withdraw");
        collectedFees[token] = 0;
        bool success = IERC20(token).transfer(msg.sender, fees);
        require(success, "Transfer failed");
        emit FeesWithdrawn(token, fees);
    }

    function maxFlashLoan(address token) external view returns (uint256) {
        if (!supportedTokens[token]) return 0;
        return IERC20(token).balanceOf(address(this)) - collectedFees[token];
    }

    function flashFee(uint256 amount) external view returns (uint256) {
        return (amount * feePercentage) / 10000;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Zero address");
        owner = newOwner;
    }
}