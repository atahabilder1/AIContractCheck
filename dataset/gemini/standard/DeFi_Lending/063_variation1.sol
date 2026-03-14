// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract PeerToPeerLending {

    struct Loan {
        address borrower;
        address lender;
        uint256 principal;
        uint256 interestRate; // Annual interest rate in basis points (e.g., 500 for 5%)
        uint256 term; // Loan term in seconds
        uint256 startTime;
        uint256 collateralAmount;
        address collateralToken; // Address of the ERC20 token used as collateral
        bool active;
        bool repaid;
        bool defaulted;
    }

    mapping(uint256 => Loan) public loans;
    uint256 public loanCounter;

    event LoanCreated(
        uint256 indexed loanId,
        address indexed borrower,
        address lender,
        uint256 principal,
        uint256 interestRate,
        uint256 term,
        uint256 collateralAmount,
        address collateralToken
    );
    event LoanAccepted(uint256 indexed loanId, address indexed borrower, address indexed lender);
    event LoanFunded(uint256 indexed loanId, address indexed borrower, address indexed lender);
    event LoanRepaid(uint256 indexed loanId, address indexed borrower, address indexed lender);
    event LoanDefaulted(uint256 indexed loanId, address indexed borrower, address indexed lender);
    event CollateralReturned(uint256 indexed loanId, address indexed borrower, address indexed lender);

    // Function to create a new loan request
    function createLoanRequest(
        uint256 _principal,
        uint256 _interestRate, // in basis points
        uint256 _term, // in seconds
        uint256 _collateralAmount,
        address _collateralToken
    ) public payable {
        require(_principal > 0, "Principal must be greater than 0");
        require(_interestRate > 0, "Interest rate must be greater than 0");
        require(_term > 0, "Term must be greater than 0");
        require(_collateralAmount > 0, "Collateral amount must be greater than 0");
        require(_collateralToken != address(0), "Invalid collateral token address");

        uint256 loanId = loanCounter++;
        loans[loanId] = Loan({
            borrower: msg.sender,
            lender: address(0), // Lender will be assigned later
            principal: _principal,
            interestRate: _interestRate,
            term: _term,
            startTime: 0, // Will be set when funded
            collateralAmount: _collateralAmount,
            collateralToken: _collateralToken,
            active: false,
            repaid: false,
            defaulted: false
        });

        emit LoanCreated(
            loanId,
            msg.sender,
            address(0),
            _principal,
            _interestRate,
            _term,
            _collateralAmount,
            _collateralToken
        );
    }

    // Function for a lender to accept a loan request
    function acceptLoan(uint256 _loanId) public payable {
        Loan storage loan = loans[_loanId];
        require(loan.borrower != address(0), "Loan does not exist");
        require(loan.lender == address(0), "Loan already has a lender");
        require(loan.borrower != msg.sender, "Borrower cannot be the lender");
        require(loan.active == false, "Loan is already active");

        // In a real-world scenario, you'd want to verify the collateral token
        // and potentially have a mechanism for the lender to approve the collateral.
        // For simplicity, we assume the borrower has already deposited collateral off-chain
        // or will deposit it before funding.

        loan.lender = msg.sender;
        emit LoanAccepted(_loanId, loan.borrower, msg.sender);
    }

    // Function for the borrower to deposit collateral and fund the loan
    function fundLoan(uint256 _loanId) public payable {
        Loan storage loan = loans[_loanId];
        require(loan.borrower != address(0), "Loan does not exist");
        require(loan.lender == msg.sender, "Only the assigned lender can fund");
        require(loan.active == false, "Loan is already active");
        require(loan.borrower != address(0), "Borrower has not been set");

        // Transfer principal from lender to borrower
        (bool success,) = payable(loan.borrower).call{value: loan.principal}("");
        require(success, "Failed to transfer principal to borrower");

        // Transfer collateral from borrower to this contract (escrow)
        // This assumes the borrower has approved the transfer of collateralToken
        // to this contract beforehand.
        IERC20 collateralTokenContract = IERC20(loan.collateralToken);
        require(collateralTokenContract.transferFrom(loan.borrower, address(this), loan.collateralAmount), "Failed to transfer collateral to escrow");

        loan.startTime = block.timestamp;
        loan.active = true;
        emit LoanFunded(_loanId, loan.borrower, loan.lender);
    }

    // Function for the borrower to repay the loan
    function repayLoan(uint256 _loanId) public payable {
        Loan storage loan = loans[_loanId];
        require(loan.borrower != address(0), "Loan does not exist");
        require(loan.active == true, "Loan is not active");
        require(loan.repaid == false, "Loan already repaid");
        require(loan.defaulted == false, "Loan has defaulted");
        require(loan.borrower == msg.sender, "Only the borrower can repay");
        require(block.timestamp >= loan.startTime + loan.term, "Loan term not yet expired");

        // Calculate total amount due (principal + interest)
        uint256 totalDue = calculateTotalAmountDue(loan);
        require(msg.value >= totalDue, "Insufficient payment");

        // Transfer payment to lender
        (bool success,) = payable(loan.lender).call{value: totalDue}("");
        require(success, "Failed to transfer repayment to lender");

        // Return any overpayment to borrower
        if (msg.value > totalDue) {
            (success,) = payable(msg.sender).call{value: msg.value - totalDue}("");
            require(success, "Failed to return overpayment to borrower");
        }

        loan.repaid = true;
        loan.active = false;
        emit LoanRepaid(_loanId, loan.borrower, loan.lender);
    }

    // Function to claim collateral if loan is not repaid
    function claimCollateral(uint256 _loanId) public {
        Loan storage loan = loans[_loanId];
        require(loan.borrower != address(0), "Loan does not exist");
        require(loan.active == true, "Loan is not active");
        require(loan.repaid == false, "Loan has been repaid");
        require(loan.defaulted == false, "Loan has already defaulted");
        require(loan.lender == msg.sender, "Only the lender can claim collateral");
        require(block.timestamp >= loan.startTime + loan.term, "Loan term not yet expired");

        loan.defaulted = true;
        loan.active = false;

        // Transfer collateral to lender
        IERC20 collateralTokenContract = IERC20(loan.collateralToken);
        require(collateralTokenContract.transfer(loan.lender, loan.collateralAmount), "Failed to transfer collateral to lender");

        emit LoanDefaulted(_loanId, loan.borrower, loan.lender);
    }

    // Function for the borrower to retrieve collateral after repayment
    function retrieveCollateral(uint256 _loanId) public {
        Loan storage loan = loans[_loanId];
        require(loan.borrower != address(0), "Loan does not exist");
        require(loan.repaid == true, "Loan has not been repaid");
        require(loan.borrower == msg.sender, "Only the borrower can retrieve collateral");

        // Transfer collateral back to borrower
        IERC20 collateralTokenContract = IERC20(loan.collateralToken);
        require(collateralTokenContract.transfer(loan.borrower, loan.collateralAmount), "Failed to transfer collateral back to borrower");

        emit CollateralReturned(_loanId, loan.borrower, loan.lender);
    }

    // Helper function to calculate total amount due (principal + interest)
    function calculateTotalAmountDue(Loan storage _loan) internal view returns (uint256) {
        uint256 elapsedTime = block.timestamp - _loan.startTime;
        uint256 interest = (_loan.principal * _loan.interestRate * elapsedTime) / (100 * 365 days); // Simple interest calculation
        return _loan.principal + interest;
    }

    // Fallback function to receive Ether
    receive() external payable {}
}

interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
}