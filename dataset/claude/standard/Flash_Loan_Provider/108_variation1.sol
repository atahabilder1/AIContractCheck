// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface IFlashBorrower {
    function onFlashLoan(
        address initiator,
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external returns (bytes32);
}

contract FlashLoanAndMint is ERC20, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    bytes32 private constant CALLBACK_SUCCESS = keccak256("IFlashBorrower.onFlashLoan");

    uint256 public flashLoanFeeRate = 9; // 0.09% (basis points / 100)
    uint256 public flashMintFeeRate = 10; // 0.1%
    uint256 private constant FEE_DENOMINATOR = 10000;

    uint256 public maxFlashMint = 1_000_000 * 1e18;

    mapping(address => bool) public supportedTokens;
    address public feeRecipient;

    event FlashLoan(address indexed borrower, address indexed token, uint256 amount, uint256 fee);
    event FlashMint(address indexed borrower, uint256 amount, uint256 fee);
    event TokenSupported(address indexed token, bool supported);
    event FeeRatesUpdated(uint256 loanFeeRate, uint256 mintFeeRate);
    event MaxFlashMintUpdated(uint256 newMax);

    constructor(
        string memory name_,
        string memory symbol_,
        address _feeRecipient
    ) ERC20(name_, symbol_) Ownable(msg.sender) {
        require(_feeRecipient != address(0), "Zero fee recipient");
        feeRecipient = _feeRecipient;
    }

    function flashLoan(
        address token,
        uint256 amount,
        bytes calldata data
    ) external nonReentrant {
        require(supportedTokens[token], "Token not supported");
        require(amount > 0, "Zero amount");

        uint256 fee = (amount * flashLoanFeeRate) / FEE_DENOMINATOR;
        uint256 balanceBefore = IERC20(token).balanceOf(address(this));
        require(balanceBefore >= amount, "Insufficient liquidity");

        IERC20(token).safeTransfer(msg.sender, amount);

        bytes32 result = IFlashBorrower(msg.sender).onFlashLoan(
            msg.sender,
            token,
            amount,
            fee,
            data
        );
        require(result == CALLBACK_SUCCESS, "Callback failed");

        uint256 balanceAfter = IERC20(token).balanceOf(address(this));
        require(balanceAfter >= balanceBefore + fee, "Repayment insufficient");

        if (fee > 0) {
            IERC20(token).safeTransfer(feeRecipient, fee);
        }

        emit FlashLoan(msg.sender, token, amount, fee);
    }

    function flashMint(uint256 amount, bytes calldata data) external nonReentrant {
        require(amount > 0, "Zero amount");
        require(amount <= maxFlashMint, "Exceeds max flash mint");

        uint256 fee = (amount * flashMintFeeRate) / FEE_DENOMINATOR;

        _mint(msg.sender, amount);

        bytes32 result = IFlashBorrower(msg.sender).onFlashLoan(
            msg.sender,
            address(this),
            amount,
            fee,
            data
        );
        require(result == CALLBACK_SUCCESS, "Callback failed");

        uint256 repayment = amount + fee;
        require(balanceOf(msg.sender) >= repayment, "Insufficient repayment balance");

        _burn(msg.sender, amount);

        if (fee > 0) {
            _transfer(msg.sender, feeRecipient, fee);
        }

        emit FlashMint(msg.sender, amount, fee);
    }

    function setSupportedToken(address token, bool supported) external onlyOwner {
        require(token != address(0), "Zero address");
        supportedTokens[token] = supported;
        emit TokenSupported(token, supported);
    }

    function setFeeRates(uint256 _loanFeeRate, uint256 _mintFeeRate) external onlyOwner {
        require(_loanFeeRate <= 500 && _mintFeeRate <= 500, "Fee too high");
        flashLoanFeeRate = _loanFeeRate;
        flashMintFeeRate = _mintFeeRate;
        emit FeeRatesUpdated(_loanFeeRate, _mintFeeRate);
    }

    function setMaxFlashMint(uint256 _maxFlashMint) external onlyOwner {
        maxFlashMint = _maxFlashMint;
        emit MaxFlashMintUpdated(_maxFlashMint);
    }

    function setFeeRecipient(address _feeRecipient) external onlyOwner {
        require(_feeRecipient != address(0), "Zero address");
        feeRecipient = _feeRecipient;
    }

    function depositLiquidity(address token, uint256 amount) external {
        require(supportedTokens[token], "Token not supported");
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
    }

    function withdrawLiquidity(address token, uint256 amount) external onlyOwner {
        IERC20(token).safeTransfer(msg.sender, amount);
    }

    function maxFlashLoan(address token) external view returns (uint256) {
        if (token == address(this)) return maxFlashMint;
        if (!supportedTokens[token]) return 0;
        return IERC20(token).balanceOf(address(this));
    }

    function flashFee(address token, uint256 amount) external view returns (uint256) {
        if (token == address(this)) return (amount * flashMintFeeRate) / FEE_DENOMINATOR;
        require(supportedTokens[token], "Token not supported");
        return (amount * flashLoanFeeRate) / FEE_DENOMINATOR;
    }
}