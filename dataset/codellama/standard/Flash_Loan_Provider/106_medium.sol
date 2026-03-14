// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-solidity/contracts/math/SafeMath.sol";
import "https://github.com/OpenZeppelin/openzeppelin-solidity/contracts/utils/ReentrancyGuard.sol";
import "https://github.com/OpenZeppelin/openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";

contract FlashLoanProvider is ReentrancyGuard {
    using SafeMath for uint256;

    struct Loan {
        address borrower;
        address token;
        uint256 amount;
        uint256 duration;
        uint256 repaymentAmount;
        uint256 fees;
        uint256 timestamp;
    }

    mapping(address => mapping(address => uint256)) public loanAmount;
    mapping(address => mapping(address => uint256)) public loanDuration;
    mapping(address => mapping(address => uint256)) public loanRepaymentAmount;
    mapping(address => mapping(address => uint256)) public loanFees;
    mapping(address => mapping(address => uint256)) public loanTimestamp;

    event LoanTaken(address borrower, address token, uint256 amount, uint256 duration, uint256 repaymentAmount, uint256 fees, uint256 timestamp);

    function takeLoan(address token, uint256 amount, uint256 duration) external nonReentrant {
        require(token != address(0), "Invalid token address");
        require(amount > 0, "Invalid loan amount");
        require(duration > 0, "Invalid loan duration");

        Loan memory loan = Loan(msg.sender, token, amount, duration, 0, 0, block.timestamp);
        loanAmount[token][msg.sender] = amount;
        loanDuration[token][msg.sender] = duration;
        loanRepaymentAmount[token][msg.sender] = 0;
        loanFees[token][msg.sender] = 0;
        loanTimestamp[token][msg.sender] = block.timestamp;

        emit LoanTaken(msg.sender, token, amount, duration, 0, 0, block.timestamp);
    }

    function repayLoan(address token, uint256 amount) external nonReentrant {
        require(amount > 0, "Invalid repayment amount");
        require(loanAmount[token][msg.sender] > 0, "Loan not taken");

        uint256 fees = loanFees[token][msg.sender];
        uint256 repaymentAmount = loanRepaymentAmount[token][msg.sender];
        uint256 duration = loanDuration[token][msg.sender];
        uint256 timestamp = loanTimestamp[token][msg.sender];

        require(amount >= repaymentAmount, "Insufficient repayment amount");

        IERC20(token).transferFrom(msg.sender, address(this), amount);
        IERC20(token).transfer(msg.sender, amount - repaymentAmount);

        loanRepaymentAmount[token][msg.sender] = 0;
        loanFees[token][msg.sender] = 0;
        loanTimestamp[token][msg.sender] = block.timestamp;

        emit LoanTaken(msg.sender, token, amount, duration, repaymentAmount, fees, timestamp);
    }

    function setFees(address token, uint256 fees) external {
        require(fees > 0, "Invalid fees");
        require(loanAmount[token][msg.sender] > 0, "Loan not taken");

        loanFees[token][msg.sender] = fees;
    }

    function getLoanAmount(address token, address borrower) external view returns (uint256) {
        return loanAmount[token][borrower];
    }

    function getLoanDuration(address token, address borrower) external view returns (uint256) {
        return loanDuration[token][borrower];
    }

    function getLoanRepaymentAmount(address token, address borrower) external view returns (uint256) {
        return loanRepaymentAmount[token][borrower];
    }

    function getLoanFees(address token, address borrower) external view returns (uint256) {
        return loanFees[token][borrower];
    }

    function getLoanTimestamp(address token, address borrower) external view returns (uint256) {
        return loanTimestamp[token][borrower];
    }
}