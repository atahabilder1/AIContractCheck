// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract DeFiLending is Ownable, Pausable {

    // Struct to store user deposit information
    struct Deposit {
        uint256 amount;
        uint256 depositTime;
    }

    // Mapping from user address to their deposit details
    mapping(address => Deposit) public userDeposits;

    // Address of the underlying ERC20 token
    IERC20 public immutable token;

    // Interest rate (e.g., 5% per year) - for simplicity, not dynamically managed
    uint256 public constant INTEREST_RATE_PER_YEAR = 5; // 5%

    // Emergency admin address
    address public emergencyAdmin;

    // Event for successful deposit
    event Deposited(address indexed user, uint256 amount);
    // Event for successful withdrawal
    event Withdrawn(address indexed user, uint256 amount);
    // Event for emergency withdrawal by admin
    event EmergencyWithdraw(address indexed admin, address indexed recipient, uint256 amount);
    // Event for pausing operations
    event Paused();
    // Event for resuming operations
    event Resumed();
    // Event for setting emergency admin
    event EmergencyAdminSet(address indexed newAdmin);

    constructor(address _tokenAddress) {
        token = IERC20(_tokenAddress);
    }

    /**
     * @dev Sets the emergency admin. Only the owner can call this.
     * @param _emergencyAdmin The address of the new emergency admin.
     */
    function setEmergencyAdmin(address _emergencyAdmin) public onlyOwner {
        emergencyAdmin = _emergencyAdmin;
        emit EmergencyAdminSet(_emergencyAdmin);
    }

    /**
     * @dev Deposits tokens into the lending pool.
     * @param _amount The amount of tokens to deposit.
     */
    function deposit(uint256 _amount) public whenNotPaused {
        require(_amount > 0, "Deposit amount must be greater than zero.");
        require(token.transferFrom(msg.sender, address(this), _amount), "Token transfer failed.");

        userDeposits[msg.sender] = Deposit({
            amount: userDeposits[msg.sender].amount + _amount,
            depositTime: block.timestamp
        });

        emit Deposited(msg.sender, _amount);
    }

    /**
     * @dev Calculates the current balance for a user, including accrued interest.
     * @param _user The address of the user.
     * @return The total balance including interest.
     */
    function getUserBalance(address _user) public view returns (uint256) {
        Deposit storage depositInfo = userDeposits[_user];
        if (depositInfo.amount == 0) {
            return 0;
        }

        uint256 timeElapsed = block.timestamp - depositInfo.depositTime; // In seconds
        // Calculate interest in basis points (e.g., 5% = 500 basis points)
        // This is a simplified interest calculation and does not account for compounding daily/hourly.
        // For a real-world scenario, more sophisticated interest calculation is needed.
        uint256 interest = (depositInfo.amount * INTEREST_RATE_PER_YEAR * timeElapsed) / (100 * 365 * 24 * 60 * 60);

        return depositInfo.amount + interest;
    }

    /**
     * @dev Withdraws tokens from the lending pool.
     * @param _amount The amount of tokens to withdraw.
     */
    function withdraw(uint256 _amount) public whenNotPaused {
        require(_amount > 0, "Withdrawal amount must be greater than zero.");

        uint256 userBalance = getUserBalance(msg.sender);
        require(userBalance >= _amount, "Insufficient balance.");

        // Update deposit amount to reflect withdrawal
        userDeposits[msg.sender].amount -= _amount;
        // Reset deposit time if the entire balance is withdrawn to avoid interest calculation on zero
        if (userDeposits[msg.sender].amount == 0) {
            userDeposits[msg.sender].depositTime = 0;
        } else {
            // If only partially withdrawn, update deposit time to current for future interest calculation
            userDeposits[msg.sender].depositTime = block.timestamp;
        }

        require(token.transfer(msg.sender, _amount), "Token transfer failed.");

        emit Withdrawn(msg.sender, _amount);
    }

    /**
     * @dev Emergency function to pause all operations. Only the owner can call this.
     */
    function pause() public onlyOwner {
        _pause();
        emit Paused();
    }

    /**
     * @dev Resumes all operations. Only the owner can call this.
     */
    function resume() public onlyOwner {
        _unpause();
        emit Resumed();
    }

    /**
     * @dev Emergency function to withdraw all tokens held by the contract.
     *      Can only be called by the emergency admin.
     * @param _recipient The address to send the withdrawn tokens to.
     */
    function emergencyWithdrawAll(address _recipient) public {
        require(msg.sender == emergencyAdmin, "Only emergency admin can call this function.");
        require(token.balanceOf(address(this)) > 0, "No tokens to withdraw.");
        require(_recipient != address(0), "Invalid recipient address.");

        uint256 balance = token.balanceOf(address(this));
        require(token.transfer(_recipient, balance), "Emergency withdrawal failed.");

        emit EmergencyWithdraw(msg.sender, _recipient, balance);
    }

    /**
     * @dev Fallback function to receive Ether, though this contract primarily deals with ERC20 tokens.
     */
    receive() external payable {}

    /**
     * @dev Returns the total balance of tokens held by the contract.
     * @return The total token balance.
     */
    function getContractBalance() public view returns (uint256) {
        return token.balanceOf(address(this));
    }
}