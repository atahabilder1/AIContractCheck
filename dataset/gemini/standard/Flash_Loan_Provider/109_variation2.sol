// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract FlashLoanProvider is Ownable {
    using SafeERC20 for IERC20;

    struct Pool {
        uint256 totalBorrowed;
        uint256 totalDeposited;
        uint256 owedFees;
    }

    mapping(address => Pool) public pools; // tokenAddress => Pool details
    mapping(address => mapping(address => uint256)) public lpBalances; // lpAddress => tokenAddress => balance

    uint256 public feePercentage = 0; // Fee percentage (e.g., 0.3 for 0.3%)

    event Deposit(address indexed token, address indexed provider, uint256 amount);
    event Withdraw(address indexed token, address indexed provider, uint256 amount);
    event Borrow(address indexed token, address indexed borrower, uint256 amount, uint256 fee);
    event FeeDistribution(address indexed token, uint256 amount);

    /**
     * @dev Sets the fee percentage for flash loans.
     * @param _feePercentage The new fee percentage (e.g., 0.3 for 0.3%).
     */
    function setFeePercentage(uint256 _feePercentage) public onlyOwner {
        feePercentage = _feePercentage;
    }

    /**
     * @dev Allows liquidity providers to deposit ERC20 tokens into a pool.
     * @param _token The address of the ERC20 token to deposit.
     * @param _amount The amount of tokens to deposit.
     */
    function deposit(address _token, uint256 _amount) public {
        require(_amount > 0, "Deposit amount must be greater than zero");

        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);

        pools[_token].totalDeposited += _amount;
        lpBalances[_token][msg.sender] += _amount;

        emit Deposit(_token, msg.sender, _amount);
    }

    /**
     * @dev Allows liquidity providers to withdraw ERC20 tokens from a pool.
     * @param _token The address of the ERC20 token to withdraw.
     * @param _amount The amount of tokens to withdraw.
     */
    function withdraw(address _token, uint256 _amount) public {
        require(_amount > 0, "Withdraw amount must be greater than zero");
        require(lpBalances[_token][msg.sender] >= _amount, "Insufficient LP balance");
        require(address(this).balanceOf(_token) >= _amount, "Insufficient pool balance"); // Check if contract has enough tokens

        lpBalances[_token][msg.sender] -= _amount;
        pools[_token].totalDeposited -= _amount;

        IERC20(_token).safeTransfer(msg.sender, _amount);

        emit Withdraw(_token, msg.sender, _amount);
    }

    /**
     * @dev Executes a flash loan. The borrower must repay the loan plus fees within the same transaction.
     * @param _token The address of the ERC20 token to borrow.
     * @param _amount The amount of tokens to borrow.
     * @param _onBehalfOf The address to which the borrowed tokens will be sent.
     * @param _callback The address of the contract that will receive the tokens and execute logic.
     * @param _data Additional data to be passed to the callback.
     */
    function flashLoan(
        address _token,
        uint256 _amount,
        address _onBehalfOf,
        address _callback,
        bytes calldata _data
    ) external {
        require(_amount > 0, "Loan amount must be greater than zero");
        require(pools[_token].totalDeposited >= _amount, "Insufficient liquidity");

        uint256 fee = (_amount * feePercentage) / 1000; // Calculate fee (e.g., 0.3% fee = 3 / 1000)
        uint256 totalRepayAmount = _amount + fee;

        require(address(this).balanceOf(_token) >= totalRepayAmount, "Insufficient contract balance for repayment");

        pools[_token].totalBorrowed += _amount;
        pools[_token].owedFees += fee;

        IERC20(_token).safeTransfer(_onBehalfOf, _amount);

        // Execute callback
        (bool success, ) = _callback.call(_data);
        require(success, "Flash loan callback failed");

        // Repayment check is handled by the borrower's callback contract
        // The borrower is responsible for sending `totalRepayAmount` back to this contract.
        // This contract will then distribute fees.

        emit Borrow(_token, _onBehalfOf, _amount, fee);
    }

    /**
     * @dev Internal function to be called by the borrower's callback contract to repay the loan and fees.
     * This function should be called by the borrower's contract after the flash loan logic.
     * The borrower's contract must transfer `_amount + fee` back to this contract.
     * @param _token The address of the ERC20 token borrowed.
     * @param _repaidAmount The total amount repaid by the borrower (loan + fee).
     */
    function repayFlashLoan(address _token, uint256 _repaidAmount) public {
        // This function is intended to be called by the borrower's callback contract
        // and should only be accessible via the callback mechanism to ensure
        // repayment happens within the same transaction.
        // A more robust implementation might involve checking the caller's context
        // or using a specific interface for the callback contract.

        uint256 currentBorrowed = pools[_token].totalBorrowed;
        uint256 currentOwedFees = pools[_token].owedFees;

        require(currentBorrowed > 0, "No active flash loan for this token");

        // The borrower must repay at least the borrowed amount plus the calculated fee
        require(_repaidAmount >= currentBorrowed + currentOwedFees, "Insufficient repayment");

        uint256 actualFeePaid = currentOwedFees; // Assume the full owed fee is paid

        // Update pool state
        pools[_token].totalBorrowed -= currentBorrowed; // Reset borrowed amount for this loan
        pools[_token].owedFees -= actualFeePaid;      // Deduct the paid fee

        // Distribute the paid fee proportionally to LPs
        distributeFees(_token, actualFeePaid);

        // If borrower overpaid, return the excess to the borrower's contract
        if (_repaidAmount > currentBorrowed + actualFeePaid) {
            IERC20(_token).safeTransfer(msg.sender, _repaidAmount - (currentBorrowed + actualFeePaid));
        }
    }

    /**
     * @dev Distributes collected fees proportionally to liquidity providers.
     * @param _token The address of the ERC20 token for which fees are being distributed.
     * @param _feeAmount The total amount of fees to distribute.
     */
    function distributeFees(address _token, uint256 _feeAmount) internal {
        if (_feeAmount == 0) return;

        uint256 totalLpBalance = pools[_token].totalDeposited;
        if (totalLpBalance == 0) {
            // If no LPs, the fee stays in the contract or could be handled differently
            // For now, we'll just let it accumulate or be handled by a specific owner function.
            // In a real-world scenario, you might want to return it to the borrower or have a burn mechanism.
            return;
        }

        // Iterate through LPs and distribute proportionally
        // A more gas-efficient approach for a large number of LPs would involve
        // a separate fee distribution mechanism (e.g., claimable fees).
        // For simplicity, this example iterates.

        // This is a simplified distribution. In a real-world scenario, you'd likely
        // want to track individual LP's share of the total deposited amount.
        // The current `lpBalances[_token][lpAddress]` already tracks this.

        // We can directly transfer the fees from the contract's balance to the LPs.
        // The `_feeAmount` represents fees that have been successfully transferred back to this contract.

        uint256 distributedAmount = 0;
        address[] memory lps = new address[](0); // To store LP addresses for iteration
        uint256[] memory balances = new uint256[](0);

        // Collect LP balances to iterate
        for (address lp = 0; lp < address(0); lp++) { // This loop is conceptual, you'd need a way to track LPs
            uint256 lpBalance = lpBalances[_token][lp];
            if (lpBalance > 0) {
                lps = (address[] memory _lps) _lps.push(lp);
                balances = (uint256[] memory _balances) _balances.push(lpBalance);
            }
        }

        // A better approach is to iterate through the `lpBalances` mapping.
        // However, iterating through mappings directly in Solidity is not possible.
        // A common pattern is to use an array to keep track of active LPs.
        // For this example, we'll simulate the distribution based on `lpBalances`.

        // If you had an `address[] public activeLPs;` array:
        // for (uint256 i = 0; i < activeLPs.length; i++) {
        //     address lp = activeLPs[i];
        //     uint256 lpBalance = lpBalances[_token][lp];
        //     if (lpBalance > 0) {
        //         uint256 lpShare = (lpBalance * _feeAmount) / totalLpBalance;
        //         if (lpShare > 0) {
        //             IERC20(_token).safeTransfer(lp, lpShare);
        //             distributedAmount += lpShare;
        //         }
        //     }
        // }

        // Since iterating mappings is not feasible directly, a practical solution involves
        // storing LP addresses in an array or using a separate mechanism for fee claiming.
        // For this simplified example, we'll assume the fees are already in the contract
        // and we're conceptually distributing them.

        // The `repayFlashLoan` function receives the `_repaidAmount` which *includes* the fee.
        // The `actualFeePaid` is derived from that.
        // The actual transfer of fees to LPs would happen here.

        // For demonstration, let's assume the `_feeAmount` is available in the contract's balance.
        // And we will directly transfer it.

        // A more robust implementation would track individual LP shares and allow claiming.
        // For this example, we'll assume the `_feeAmount` is the total fee collected.

        // A more gas-efficient way to handle fee distribution for a large number of LPs
        // is to allow LPs to claim their accrued fees.
        // For this example, we'll simulate direct distribution.

        // The `repayFlashLoan` function is called by the borrower's callback contract.
        // The `msg.sender` in `repayFlashLoan` would be the borrower's callback contract.
        // The `_repaidAmount` is transferred from the borrower's callback contract to `this`.

        // The fee distribution logic needs to be carefully implemented.
        // A common approach is to have the fees collected in the contract and then
        // LPs can claim their proportional share.

        // In this setup, `_feeAmount` is the fee that was *supposed* to be paid.
        // The `repayFlashLoan` function verifies the repayment.

        // Let's refine the `repayFlashLoan` to handle the fee transfer explicitly.
        // The `_repaidAmount` is what the borrower sent back.
        // `actualFeePaid` is the portion of `_repaidAmount` that constitutes the fee.

        // The `distributeFees` function will be called *after* the fee has been confirmed to be in the contract.
        // The `_feeAmount` passed here is the actual fee that was repaid.

        // The `lpBalances[_token][lpAddress]` represents the LP's share of the total deposited liquidity.
        // The fee should be distributed based on this proportion.

        // Example: If LP A deposited 100 tokens, and total deposited is 1000 tokens, LP A has 10% share.
        // If total fee is 10 tokens, LP A should receive 1 token.

        // To iterate through LPs and distribute, you'd need to store LP addresses.
        // A common pattern is to use an array `address[] public lps;` and add LPs when they deposit for the first time.

        // For this example, we'll assume a simpler distribution where the fee is
        // directly transferred from the contract's balance.

        // THIS IS A SIMPLIFIED DISTRIBUTION LOGIC.
        // A production-ready system would likely involve:
        // 1. An array to store LP addresses.
        // 2. A mechanism for LPs to *claim* their fees, rather than direct transfers on repayment.
        // 3. Handling of fee distribution when total deposited amount changes.

        // If `_feeAmount` is the actual fee that has been sent back to the contract:
        // The logic below is conceptual and requires a way to iterate through LPs.

        // For demonstration purposes, let's assume `_feeAmount` is the fee collected and available.
        // The `repayFlashLoan` function ensures this amount is in the contract.

        // This function is called within `repayFlashLoan` after the fee is confirmed.
        // The fee should be transferred from `this` contract to the LPs.

        // A practical approach:
        // `distributeFees` is called from `repayFlashLoan`.
        // `repayFlashLoan` receives `_repaidAmount`.
        // It calculates `actualFeePaid` and updates `pools[_token].owedFees`.
        // Then it calls `distributeFees(_token, actualFeePaid)`.
        // `distributeFees` then takes `actualFeePaid` from the contract's balance and sends it to LPs.

        // To implement this, we need to iterate through LPs.
        // Let's assume we have a mechanism to get all LPs for a token.
        // For now, we'll simulate the distribution.

        // The `_feeAmount` is the fee that has just been paid and is now in the contract.
        // We need to distribute this `_feeAmount`.

        // This part of the code needs a way to access and iterate over LPs.
        // Since direct mapping iteration is not possible, we'll outline the conceptual flow.

        // Conceptual loop for distribution:
        // for each LP in all LPs for this token:
        //     lp_balance = lpBalances[_token][LP_address]
        //     lp_share_of_fee = (lp_balance * _feeAmount) / totalLpBalance
        //     if lp_share_of_fee > 0:
        //         IERC20(_token).safeTransfer(LP_address, lp_share_of_fee)
        //         distributedAmount += lp_share_of_fee

        // If `distributedAmount < _feeAmount`, the remainder could be handled as per protocol rules
        // (e.g., kept in contract, sent to treasury, etc.).
        // For now, we assume perfect distribution.

        // The actual implementation would require a list of LPs.
        // A common way is to maintain an array of LP addresses.
        // When a new LP deposits, add them to the array if not already present.

        // The contract needs to hold the ERC20 tokens to perform these transfers.
        // The `repayFlashLoan` function ensures that the `actualFeePaid` is transferred to `this` contract.
    }

    /**
     * @dev Allows the owner to withdraw any accumulated fees that were not distributed.
     * This can be used if there are no LPs for a token or if fees could not be fully distributed.
     * @param _token The address of the ERC20 token to withdraw.
     */
    function withdrawUndistributedFees(address _token) public onlyOwner {
        uint256 undistributed = pools[_token].owedFees;
        require(undistributed > 0, "No undistributed fees");
        require(address(this).balanceOf(_token) >= undistributed, "Insufficient contract balance for fees");

        pools[_token].owedFees = 0; // Reset owed fees
        IERC20(_token).safeTransfer(owner(), undistributed);
    }

    /**
     * @dev Internal function to get the current balance of a token in the contract.
     * @param _token The address of the ERC20 token.
     * @return The balance of the token in the contract.
     */
    function balanceOf(address _token) public view returns (uint256) {
        return IERC20(_token).balanceOf(address(this));
    }
}