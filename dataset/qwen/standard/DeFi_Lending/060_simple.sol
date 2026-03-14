// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CollateralizedLending {
    address public owner;
    uint256 public loanInterestRate; // Interest rate in percentage
    mapping(address => uint256) public collateralDeposits;
    mapping(address => uint256) public loans;

    event CollateralDeposited(address indexed user, uint256 amount);
    event LoanTakenOut(address indexed user, uint256 amount);
    event LoanRepaid(address indexed user, uint256 amount);

    constructor(uint256 _interestRate) {
        owner = msg.sender;
        loanInterestRate = _interestRate;
    }

    receive() external payable {
        depositCollateral();
    }

    function depositCollateral() public payable {
        require(msg.value > 0, "Deposit amount must be greater than 0");
        collateralDeposits[msg.sender] += msg.value;
        emit CollateralDeposited(msg.sender, msg.value);
    }

    function takeOutLoan(uint256 _amount) public {
        require(collateralDeposits[msg.sender] > 0, "No collateral deposited");
        require(_amount > 0, "Loan amount must be greater than 0");
        loans[msg.sender] += _amount;
        emit LoanTakenOut(msg.sender, _amount);
        // Assume stablecoin is sent to the borrower
    }

    function repayLoan(uint256 _amount) public {
        require(loans[msg.sender] > 0, "No loan taken out");
        require(_amount > 0, "Repayment amount must be greater than 0");
        loans[msg.sender] -= _amount;
        emit LoanRepaid(msg.sender, _amount);
        // Assume stablecoin is received from the borrower
    }

    function withdrawCollateral(uint256 _amount) public {
        require(collateralDeposits[msg.sender] >= _amount, "Insufficient collateral");
        require(loans[msg.sender] == 0, "Outstanding loan");
        collateralDeposits[msg.sender] -= _amount;
        payable(msg.sender).transfer(_amount);
    }

    function getCollateralValue(address _user) public view returns (uint256) {
        return collateralDeposits[_user];
    }

    function getLoanAmount(address _user) public view returns (uint256) {
        return loans[_user];
    }
}