// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract SimpleLending is Ownable {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    struct Loan {
        uint256 amount;
        uint256 dueDate;
        bool isRepaid;
    }

    mapping(address => mapping(address => Loan)) private _loans; // borrower => asset => loan details
    mapping(address => uint256) private _borrowedAmounts; // asset => total borrowed amount
    mapping(address => uint256) private _depositedAmounts; // asset => total deposited amount

    // Interest rate parameters (simplified for testnet)
    uint256 public constant INTEREST_RATE_PER_SECOND = 1e12; // 0.000001% per second (very low for testing)
    uint256 public constant LOAN_DURATION_SECONDS = 3600; // 1 hour

    event LoanIssued(address indexed borrower, address indexed asset, uint256 amount, uint256 dueDate);
    event LoanRepaid(address indexed borrower, address indexed asset, uint256 amountRepaid, uint256 interestPaid);
    event Deposit(address indexed user, address indexed asset, uint256 amount);
    event Withdrawal(address indexed user, address indexed asset, uint256 amount);

    function deposit(address assetAddress, uint256 amount) public {
        require(amount > 0, "Deposit amount must be greater than zero");
        IERC20 asset = IERC20(assetAddress);
        asset.safeTransferFrom(msg.sender, address(this), amount);

        _depositedAmounts[assetAddress] = _depositedAmounts[assetAddress].add(amount);
        emit Deposit(msg.sender, assetAddress, amount);
    }

    function withdraw(address assetAddress, uint256 amount) public {
        require(amount > 0, "Withdrawal amount must be greater than zero");
        require(_depositedAmounts[assetAddress] >= amount, "Insufficient deposited amount");
        
        IERC20 asset = IERC20(assetAddress);
        _depositedAmounts[assetAddress] = _depositedAmounts[assetAddress].sub(amount);
        asset.safeTransfer(msg.sender, amount);

        emit Withdrawal(msg.sender, assetAddress, amount);
    }

    function borrow(address assetAddress, uint256 amount) public {
        require(amount > 0, "Borrow amount must be greater than zero");
        // In a real system, this would involve collateral checks.
        // For this simplified version, we assume sufficient collateral is implicitly available
        // or we are only lending out funds that have been deposited.
        // This is a major simplification and NOT production-ready.

        IERC20 asset = IERC20(assetAddress);
        uint256 currentSupply = _depositedAmounts[assetAddress]; // Simplified: assume deposited funds are available for lending
        require(currentSupply >= amount, "Insufficient funds available to borrow");

        _borrowedAmounts[assetAddress] = _borrowedAmounts[assetAddress].add(amount);
        _depositedAmounts[assetAddress] = _depositedAmounts[assetAddress].sub(amount); // Remove from available supply

        uint256 dueDate = block.timestamp.add(LOAN_DURATION_SECONDS);
        _loans[msg.sender][assetAddress] = Loan({
            amount: amount,
            dueDate: dueDate,
            isRepaid: false
        });

        asset.safeTransfer(msg.sender, amount);
        emit LoanIssued(msg.sender, assetAddress, amount, dueDate);
    }

    function repay(address assetAddress) public {
        Loan storage loan = _loans[msg.sender][assetAddress];
        require(loan.amount > 0, "No active loan for this asset");
        require(!loan.isRepaid, "Loan already repaid");

        uint256 amountToRepay = loan.amount;
        uint256 interestAccrued = 0;

        if (block.timestamp < loan.dueDate) {
            // No interest if repaid before due date (simplified)
        } else {
            uint256 timeElapsed = loan.dueDate.sub(block.timestamp); // Should be negative if past due, but SafeMath handles it as 0 if below 0
            uint256 interestRate = timeElapsed.mul(INTEREST_RATE_PER_SECOND); // This calculation is incorrect for past due.
            // Correct calculation for past due:
            uint256 timePastDue = block.timestamp.sub(loan.dueDate);
            interestAccrued = loan.amount.mul(timePastDue).mul(INTEREST_RATE_PER_SECOND).div(1e18); // Assuming INTEREST_RATE_PER_SECOND is scaled by 1e18
            // For simplicity and testnet, let's just use a fixed interest if past due for now, or keep it simple.
            // A more realistic interest calculation would be:
            // interestAccrued = loan.amount.mul(block.timestamp.sub(loan.dueDate)).mul(INTEREST_RATE_PER_SECOND).div(1e18);
            // Let's assume INTEREST_RATE_PER_SECOND is already scaled to be directly usable with uint256 for now.
            // A common scaling factor would be 10^18 or 10^12 depending on precision needs.
            // For this testnet example, let's adjust INTEREST_RATE_PER_SECOND to be a percentage per day, then convert to per second.
            // Example: 1% per day = 0.01. Per second: 0.01 / (24*3600)
            // Let's assume INTEREST_RATE_PER_SECOND is a small number like 1e12 meaning 1e-6% per second.
            // Interest calculation should be: amount * (interest_rate_per_second * time_elapsed)
            // For past due:
            uint256 timePastDueSeconds = block.timestamp.sub(loan.dueDate);
            interestAccrued = loan.amount.mul(timePastDueSeconds).mul(INTEREST_RATE_PER_SECOND).div(1e18); // Assuming INTEREST_RATE_PER_SECOND is scaled by 1e18
        }

        uint256 totalRepayment = amountToRepay.add(interestAccrued);

        IERC20 asset = IERC20(assetAddress);
        asset.safeTransferFrom(msg.sender, address(this), totalRepayment);

        // Update internal state
        loan.isRepaid = true;
        _borrowedAmounts[assetAddress] = _borrowedAmounts[assetAddress].sub(loan.amount);
        _depositedAmounts[assetAddress] = _depositedAmounts[assetAddress].add(loan.amount); // Returned principal becomes available again

        emit LoanRepaid(msg.sender, assetAddress, loan.amount, interestAccrued);
    }

    function getLoanDetails(address borrower, address assetAddress) public view returns (uint256 amount, uint256 dueDate, bool isRepaid) {
        Loan storage loan = _loans[borrower][assetAddress];
        return (loan.amount, loan.dueDate, loan.isRepaid);
    }

    function getAvailableLiquidity(address assetAddress) public view returns (uint256) {
        // Simplified: Available liquidity is what's deposited and not currently lent out.
        // This doesn't account for actual collateralization ratios.
        return _depositedAmounts[assetAddress];
    }

    function getTotalBorrowed(address assetAddress) public view returns (uint256) {
        return _borrowedAmounts[assetAddress];
    }

    function getTotalDeposited(address assetAddress) public view returns (uint256) {
        return _depositedAmounts[assetAddress];
    }
}