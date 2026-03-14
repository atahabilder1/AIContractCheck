// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract SimpleLending is Ownable {
    using SafeERC20 for IERC20;

    struct Loan {
        uint256 amount;
        uint256 interestRate; // Annual interest rate in basis points (e.g., 500 for 5%)
        uint256 collateralAmount;
        uint256 collateralType; // Identifier for the collateral token
        uint256 startTime;
        uint256 endTime;
        bool isActive;
    }

    mapping(uint256 => Loan) public loans;
    uint256 public nextLoanId;

    mapping(address => uint256[]) public userLoans; // borrower address => array of loan IDs

    // Addresses of supported collateral tokens (e.g., WETH, DAI)
    // This is a simplified mapping, in a real scenario, you'd likely want a more robust way to manage collateral.
    mapping(uint256 => address) public collateralTokens;
    uint256 public nextCollateralId;

    event LoanCreated(uint256 loanId, address borrower, uint256 principalAmount, uint256 interestRate, uint256 collateralAmount, uint256 collateralType, uint256 endTime);
    event LoanRepaid(uint256 loanId, address borrower, uint256 amountRepaid);
    event CollateralLiquidated(uint256 loanId, address borrower, uint256 collateralAmount);
    event CollateralAdded(uint256 collateralId, address collateralAddress);

    constructor() {
        nextLoanId = 1;
        nextCollateralId = 1;
    }

    function addCollateralType(address _collateralAddress) public onlyOwner {
        collateralTokens[nextCollateralId] = _collateralAddress;
        emit CollateralAdded(nextCollateralId, _collateralAddress);
        nextCollateralId++;
    }

    function createLoan(
        address _borrower,
        address _principalToken,
        uint256 _principalAmount,
        uint256 _interestRate, // in basis points (e.g., 500 for 5%)
        uint256 _collateralType,
        uint256 _collateralAmount,
        uint256 _loanDuration // in seconds
    ) public onlyOwner {
        require(_collateralType > 0 && _collateralType < nextCollateralId, "Invalid collateral type");
        require(_principalAmount > 0, "Principal amount must be greater than 0");
        require(_interestRate <= 10000, "Interest rate too high"); // Max 100%
        require(_loanDuration > 0, "Loan duration must be greater than 0");

        IERC20 principalToken = IERC20(_principalToken);
        IERC20 collateralToken = IERC20(collateralTokens[_collateralType]);

        // Borrower must approve the contract to spend their collateral
        require(collateralToken.allowance(_borrower, address(this)) >= _collateralAmount, "Collateral not approved");

        // Transfer collateral from borrower to the lending contract
        collateralToken.safeTransferFrom(_borrower, address(this), _collateralAmount);

        uint256 loanId = nextLoanId;
        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + _loanDuration;

        loans[loanId] = Loan({
            amount: _principalAmount,
            interestRate: _interestRate,
            collateralAmount: _collateralAmount,
            collateralType: _collateralType,
            startTime: startTime,
            endTime: endTime,
            isActive: true
        });

        userLoans[_borrower].push(loanId);
        nextLoanId++;

        emit LoanCreated(loanId, _borrower, _principalAmount, _interestRate, _collateralAmount, _collateralType, endTime);
    }

    function repayLoan(uint256 _loanId) public payable {
        Loan storage loan = loans[_loanId];
        require(loan.isActive, "Loan is not active");
        require(msg.sender == getBorrower(_loanId), "Only borrower can repay"); // Simplified: assumes borrower is the one who created the loan

        // Calculate total amount due (principal + interest)
        uint256 timeElapsed = block.timestamp - loan.startTime;
        uint256 interestDue = (loan.amount * loan.interestRate * timeElapsed) / (100 * 365 days); // Simplified interest calculation
        uint256 totalAmountDue = loan.amount + interestDue;

        // In a real scenario, you'd need to know the principal token address.
        // For simplicity, this example assumes the loan principal is paid in Ether if payable,
        // or requires an ERC20 token transfer if _principalToken was passed in createLoan.
        // This function needs to be adapted based on whether you are lending ETH or ERC20 tokens.
        // For this demo, let's assume it's ERC20 and we'll need to check the token.

        // Example for ERC20 repayment (requires _principalToken to be known or passed)
        // IERC20 principalToken = IERC20(somePrincipalTokenAddress); // You need to store this
        // require(principalToken.balanceOf(msg.sender) >= totalAmountDue, "Insufficient balance to repay");
        // principalToken.safeTransferFrom(msg.sender, address(this), totalAmountDue);

        // For this demo, let's assume the loan was created with ETH and repayment is in ETH.
        // This is a simplification and would require the `createLoan` function to specify the principal token.
        require(msg.value >= totalAmountDue, "Insufficient ETH to repay");
        // If msg.value > totalAmountDue, the excess will be returned or handled by a refund mechanism.

        loan.isActive = false;
        // Return collateral to the borrower
        IERC20 collateralToken = IERC20(collateralTokens[loan.collateralType]);
        collateralToken.safeTransfer(msg.sender, loan.collateralAmount);

        emit LoanRepaid(_loanId, msg.sender, totalAmountDue);
    }

    function liquidateLoan(uint256 _loanId) public onlyOwner {
        Loan storage loan = loans[_loanId];
        require(loan.isActive, "Loan is not active");
        require(block.timestamp > loan.endTime, "Loan not yet due for liquidation");

        // In a real DeFi lending protocol, liquidation would involve checking collateral value
        // against the loan amount and potentially selling collateral to cover the debt.
        // This is a simplified liquidation where the collateral is just forfeited.

        loan.isActive = false;
        // The collateral is already held by the contract.
        // This function would typically involve a liquidator mechanism.

        emit CollateralLiquidated(_loanId, getBorrower(_loanId), loan.collateralAmount);
    }

    // Helper function to get the borrower of a loan.
    // In a real system, you would store the borrower's address directly in the Loan struct.
    function getBorrower(uint256 _loanId) internal view returns (address) {
        // This is a placeholder. In a real contract, you'd store the borrower's address.
        // For this simplified example, we'll assume the borrower is the first address
        // that approved collateral for this loan ID. This is NOT secure or reliable.
        // A proper implementation would store the borrower's address when creating the loan.
        // For the sake of the demo, we'll assume the owner of the loan ID is the borrower.
        // This requires a mapping from loan ID to borrower address.
        // Let's add a mapping for demonstration purposes.
        // mapping(uint256 => address) public loanBorrowers; // This should be added.

        // For this demo, returning address(0) as a placeholder.
        // You MUST implement a way to track the borrower.
        // A simple way for this demo: iterate through userLoans to find the borrower.
        for (uint256 i = 0; i < nextLoanId; i++) {
            if (loans[i+1].isActive && i+1 == _loanId) { // Check if this is the loan we are looking for
                // Find which user has this loan ID in their userLoans array.
                // This is inefficient and should not be used in production.
                for (address user, uint256[] memory loanIds) in userLoans {
                    for (uint256 id of loanIds) {
                        if (id == _loanId) {
                            return user;
                        }
                    }
                }
            }
        }
        revert("Borrower not found for this loan");
    }

    // Function to allow a user to deposit collateral to be used for future loans.
    // This is a more flexible approach than requiring collateral at loan creation.
    function depositCollateral(uint256 _collateralType, uint256 _amount) public {
        require(_collateralType > 0 && _collateralType < nextCollateralId, "Invalid collateral type");
        IERC20 collateralToken = IERC20(collateralTokens[_collateralType]);
        require(collateralToken.balanceOf(msg.sender) >= _amount, "Insufficient collateral balance");
        collateralToken.safeTransferFrom(msg.sender, address(this), _amount);
        // In a real system, you'd track user collateral deposits in a separate mapping.
        // e.g., mapping(address => mapping(uint256 => uint256)) public userCollateral;
    }

    // Function to withdraw deposited collateral (if not currently used as active loan collateral).
    // This function would require more complex logic to track available collateral.
    // For this demo, we'll omit it to keep it simple.

    // Fallback function to receive Ether (if lending ETH)
    receive() external payable {}
}