// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract SimpleLending {
    struct Loan {
        address borrower;
        address lender;
        uint256 principal;
        uint256 interestRate; // Annual interest rate (e.g., 500 for 5%)
        uint256 startTime;
        uint256 endTime;
        bool active;
        bool repaid;
    }

    mapping(uint256 => Loan) public loans;
    uint256 public nextLoanId;
    uint256 public constant INTEREST_PRECISION = 10000; // For calculating interest precisely

    event LoanCreated(
        uint256 indexed loanId,
        address indexed borrower,
        address indexed lender,
        uint256 principal,
        uint256 interestRate,
        uint256 endTime
    );
    event LoanRepaid(uint256 indexed loanId, address indexed borrower);
    event LoanLiquidated(uint256 indexed loanId, address indexed borrower);

    modifier onlyActiveLoan(uint256 _loanId) {
        require(loans[_loanId].active, "Loan is not active");
        require(!loans[_loanId].repaid, "Loan already repaid");
        _;
    }

    modifier onlyBorrower(uint256 _loanId) {
        require(msg.sender == loans[_loanId].borrower, "Only the borrower can perform this action");
        _;
    }

    modifier onlyLender(uint256 _loanId) {
        require(msg.sender == loans[_loanId].lender, "Only the lender can perform this action");
        _;
    }

    function createLoan(
        address _borrower,
        uint256 _principal,
        uint256 _interestRate, // Annual interest rate in basis points (e.g., 500 for 5%)
        uint256 _durationInSeconds
    ) public payable {
        require(_borrower != address(0), "Invalid borrower address");
        require(_principal > 0, "Principal must be greater than zero");
        require(_interestRate <= 10000, "Interest rate cannot exceed 100%"); // Max 100% annual rate
        require(_durationInSeconds > 0, "Duration must be greater than zero");
        require(msg.value == _principal, "Sent amount must equal principal");

        uint256 loanId = nextLoanId;
        nextLoanId++;

        loans[loanId] = Loan({
            borrower: _borrower,
            lender: msg.sender,
            principal: _principal,
            interestRate: _interestRate,
            startTime: block.timestamp,
            endTime: block.timestamp + _durationInSeconds,
            active: true,
            repaid: false
        });

        emit LoanCreated(loanId, _borrower, msg.sender, _principal, _interestRate, loans[loanId].endTime);
    }

    function repayLoan(uint256 _loanId) public payable onlyActiveLoan(_loanId) onlyBorrower(_loanId) {
        Loan storage loan = loans[_loanId];
        require(!loan.repaid, "Loan already repaid");

        uint256 totalDue = calculateTotalDue(loan);
        require(msg.value >= totalDue, "Insufficient payment");

        loan.repaid = true;
        loan.active = false; // Mark as inactive after repayment

        // Refund any overpayment
        if (msg.value > totalDue) {
            payable(msg.sender).transfer(msg.value - totalDue);
        }

        // Transfer principal and interest to lender
        payable(loan.lender).transfer(totalDue);

        emit LoanRepaid(_loanId, msg.sender);
    }

    function liquidateLoan(uint256 _loanId) public onlyActiveLoan(_loanId) onlyLender(_loanId) {
        Loan storage loan = loans[_loanId];
        require(!loan.repaid, "Loan already repaid");
        require(block.timestamp > loan.endTime, "Loan is not yet past its due date for liquidation");

        loan.active = false; // Mark as inactive after liquidation

        // In a real-world scenario, liquidation would involve collateral.
        // This simple example assumes the lender can claim the principal + interest
        // from the borrower's account if the borrower doesn't repay.
        // For this standalone example, we'll just send the principal + interest to the lender.
        // This is a simplification and not a robust liquidation mechanism.

        uint256 totalDue = calculateTotalDue(loan);
        // In a real system, you'd check if the borrower has enough ETH to cover totalDue.
        // If not, you'd seize collateral. Here, we just transfer from the lender's perspective.
        // This contract doesn't hold borrower funds directly.
        // The `repayLoan` function is the primary way funds flow.
        // This `liquidateLoan` function is more of a state change and notification.

        // To simulate some fund transfer for liquidation, one might require the borrower
        // to deposit collateral upfront and the lender can claim it here.
        // Without collateral, this function is primarily for marking the loan as inactive.

        // For demonstration: if the lender has sent the principal during creation,
        // we can consider that as the "collateral" and transfer it back with interest.
        // This is a flawed assumption for a real lending protocol.

        // A more realistic approach would involve a separate collateral mechanism.
        // For this simplified example, we'll assume the lender is the one who *sent* the principal initially.
        // So, in this context, liquidation means the lender effectively "gets their money back"
        // plus interest, and the borrower forfeits it.

        // Since the `createLoan` function requires `msg.value == _principal`,
        // the lender has already sent the principal.
        // This function marks the loan as inactive and could be used to trigger off-chain actions.

        // If this were a contract holding borrower collateral, the lender would claim it here.
        // For this example, we'll assume the lender can claim the principal + interest
        // by sending it to themselves from the borrower's account if they had deposited collateral.
        // Since there's no collateral mechanism here, we'll just emit an event.

        // In a real scenario, the lender would have to initiate a transfer of collateral
        // from the borrower's deposited collateral pool to their own address.
        // Without collateral, this is just a state change.

        emit LoanLiquidated(_loanId, loan.borrower);
    }

    function calculateTotalDue(Loan storage _loan) internal view returns (uint256) {
        if (block.timestamp <= _loan.endTime) {
            return _loan.principal;
        }

        uint256 timeElapsed = block.timestamp - _loan.startTime;
        // Calculate interest for the duration of the loan
        // Interest = Principal * (Rate/10000) * (TimeElapsed / SecondsInAYear)
        // We use 365 days as a standard year for simplicity.
        uint256 secondsInAYear = 365 * 24 * 60 * 60;
        uint256 interestAccrued = (_loan.principal * _loan.interestRate * timeElapsed) / (INTEREST_PRECISION * secondsInAYear);

        return _loan.principal + interestAccrued;
    }

    function getLoanDetails(uint256 _loanId)
        public
        view
        returns (
            address borrower,
            address lender,
            uint256 principal,
            uint256 interestRate,
            uint256 startTime,
            uint256 endTime,
            bool active,
            bool repaid,
            uint256 totalDue
        )
    {
        Loan storage loan = loans[_loanId];
        return (
            loan.borrower,
            loan.lender,
            loan.principal,
            loan.interestRate,
            loan.startTime,
            loan.endTime,
            loan.active,
            loan.repaid,
            calculateTotalDue(loan)
        );
    }
}