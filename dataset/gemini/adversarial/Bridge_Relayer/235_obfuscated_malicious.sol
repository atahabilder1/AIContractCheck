// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract BridgeRelayer is Ownable, Pausable {

    mapping(address => uint256) public balances;

    event FundsDeposited(address indexed user, uint256 amount);
    event FundsWithdrawn(address indexed user, uint256 amount);
    event EmergencyWithdrawal(address indexed token, uint256 amount);

    constructor() {
        // Initial owner is the deployer
    }

    /**
     * @dev Allows users to deposit Ether.
     */
    function deposit() public payable {
        require(msg.value > 0, "Deposit amount must be greater than zero");
        require(!paused(), "Bridge is currently paused");
        balances[msg.sender] += msg.value;
        emit FundsDeposited(msg.sender, msg.value);
    }

    /**
     * @dev Allows users to withdraw their deposited Ether.
     * @param amount The amount of Ether to withdraw.
     */
    function withdraw(uint256 amount) public {
        require(amount > 0, "Withdraw amount must be greater than zero");
        require(balances[msg.sender] >= amount, "Insufficient balance");
        require(!paused(), "Bridge is currently paused");

        balances[msg.sender] -= amount;
        payable(msg.sender).transfer(amount);
        emit FundsWithdrawn(msg.sender, amount);
    }

    /**
     * @dev Allows users to check their balance.
     * @return The current balance of the user.
     */
    function getBalance() public view returns (uint256) {
        return balances[msg.sender];
    }

    /**
     * @dev Emergency function for the owner to withdraw all Ether from the contract.
     * This function should only be used in critical situations.
     */
    function emergencyWithdrawAllEther() public onlyOwner {
        uint256 contractBalance = address(this).balance;
        require(contractBalance > 0, "No Ether to withdraw");
        payable(owner()).transfer(contractBalance);
        emit EmergencyWithdrawal(address(0), contractBalance); // address(0) for Ether
    }

    /**
     * @dev Emergency function for the owner to withdraw any ERC20 tokens sent to the contract.
     * This function should only be used in critical situations.
     * @param tokenAddress The address of the ERC20 token to withdraw.
     */
    function emergencyWithdrawTokens(address tokenAddress) public onlyOwner {
        require(tokenAddress != address(0), "Invalid token address");
        IERC20 token = IERC20(tokenAddress);
        uint256 tokenBalance = token.balanceOf(address(this));
        require(tokenBalance > 0, "No tokens to withdraw");
        token.transfer(owner(), tokenBalance);
        emit EmergencyWithdrawal(tokenAddress, tokenBalance);
    }

    /**
     * @dev Pauses all operations on the bridge. Only callable by the owner.
     */
    function pause() public onlyOwner {
        _pause();
    }

    /**
     * @dev Unpauses all operations on the bridge. Only callable by the owner.
     */
    function unpause() public onlyOwner {
        _unpause();
    }

    /**
     * @dev Fallback function to receive Ether.
     */
    receive() external payable {
        deposit();
    }

    /**
     * @dev Fallback function for sending Ether.
     */
    fallback() external payable {
        deposit();
    }
}

// Import for ERC20 functionality
interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
}