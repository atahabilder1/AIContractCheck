// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract CrossChainBridge is Ownable, Pausable {

    // Events
    event FundsDeposited(address indexed user, uint256 amount);
    event FundsWithdrawn(address indexed user, uint256 amount);
    event EmergencyWithdrawal(address indexed token, address indexed recipient, uint256 amount);
    event BridgePaused();
    event BridgeResumed();

    // Mapping to store user balances
    mapping(address => uint256) public balances;

    // Administrator role for emergency functions
    address public emergencyAdmin;

    // Constructor: Set the initial owner and emergency admin
    constructor(address _emergencyAdmin) {
        _transferOwnership(msg.sender); // The deployer is the initial owner
        emergencyAdmin = _emergencyAdmin;
    }

    // Modifier to restrict access to the emergency admin
    modifier onlyEmergencyAdmin() {
        require(msg.sender == emergencyAdmin, "Caller is not the emergency admin");
        _;
    }

    // Function to deposit funds into the bridge
    function deposit(uint256 _amount) external {
        require(_amount > 0, "Deposit amount must be greater than zero");
        require(!paused(), "Bridge is paused");

        // Assuming the deposit is in native Ether for simplicity.
        // For ERC20 tokens, you would need to approve and transferFrom.
        require(msg.value == _amount, "Incorrect Ether amount sent");

        balances[msg.sender] += _amount;
        emit FundsDeposited(msg.sender, _amount);
    }

    // Function to withdraw funds from the bridge
    function withdraw(uint256 _amount) external {
        require(_amount > 0, "Withdrawal amount must be greater than zero");
        require(!paused(), "Bridge is paused");
        require(balances[msg.sender] >= _amount, "Insufficient balance");

        balances[msg.sender] -= _amount;

        // Assuming withdrawal is in native Ether.
        (bool success, ) = payable(msg.sender).call{value: _amount}("");
        require(success, "Ether withdrawal failed");

        emit FundsWithdrawn(msg.sender, _amount);
    }

    // --- Emergency Admin Functions ---

    // Function for the emergency admin to withdraw all native Ether from the contract
    function emergencyWithdrawNative() external onlyEmergencyAdmin {
        uint256 contractBalance = address(this).balance;
        require(contractBalance > 0, "No native Ether to withdraw");

        (bool success, ) = payable(emergencyAdmin).call{value: contractBalance}("");
        require(success, "Emergency native Ether withdrawal failed");

        emit EmergencyWithdrawal(address(0), emergencyAdmin, contractBalance); // address(0) for native Ether
    }

    // Function for the emergency admin to withdraw a specific ERC20 token from the contract
    function emergencyWithdrawERC20(IERC20 _token, uint256 _amount) external onlyEmergencyAdmin {
        require(_amount > 0, "Withdrawal amount must be greater than zero");
        require(_token.balanceOf(address(this)) >= _amount, "Insufficient token balance in contract");

        require(_token.transfer(emergencyAdmin, _amount), "ERC20 token withdrawal failed");

        emit EmergencyWithdrawal(address(_token), emergencyAdmin, _amount);
    }

    // Function to pause bridge operations
    function pauseBridge() external onlyOwner {
        _pause();
        emit BridgePaused();
    }

    // Function to resume bridge operations
    function resumeBridge() external onlyOwner {
        _unpause();
        emit BridgeResumed();
    }

    // Function for the owner to change the emergency admin
    function setEmergencyAdmin(address _newEmergencyAdmin) external onlyOwner {
        require(_newEmergencyAdmin != address(0), "Emergency admin cannot be the zero address");
        emergencyAdmin = _newEmergencyAdmin;
    }

    // Fallback function to receive native Ether
    receive() external payable {
        // Can be used to receive native Ether directly, or deposit logic can be here.
        // For this example, we assume deposits are made via the deposit function.
    }

    // Function to check the contract's native Ether balance
    function getNativeBalance() external view returns (uint256) {
        return address(this).balance;
    }

    // Function to check the contract's ERC20 token balance
    function getERC20Balance(IERC20 _token) external view returns (uint256) {
        return _token.balanceOf(address(this));
    }
}