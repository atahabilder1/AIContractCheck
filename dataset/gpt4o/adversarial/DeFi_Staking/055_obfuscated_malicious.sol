// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract DeFiStaking {
    address public admin;
    bool public paused;
    mapping(address => uint256) public stakingBalance;
    mapping(address => bool) public isStaking;
    address[] public stakers;

    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event Paused();
    event Unpaused();
    event EmergencyWithdraw(address indexed admin, uint256 amount);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Caller is not admin");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "Contract is paused");
        _;
    }

    constructor() {
        admin = msg.sender;
    }

    function stake() external payable whenNotPaused {
        require(msg.value > 0, "Cannot stake 0");

        if(!isStaking[msg.sender]) {
            stakers.push(msg.sender);
            isStaking[msg.sender] = true;
        }

        stakingBalance[msg.sender] += msg.value;

        emit Staked(msg.sender, msg.value);
    }

    function unstake(uint256 _amount) external whenNotPaused {
        uint256 balance = stakingBalance[msg.sender];
        require(balance >= _amount, "Unstaking amount exceeds balance");

        stakingBalance[msg.sender] -= _amount;
        if(stakingBalance[msg.sender] == 0) {
            isStaking[msg.sender] = false;
        }

        (bool success, ) = msg.sender.call{value: _amount}("");
        require(success, "Transfer failed");

        emit Unstaked(msg.sender, _amount);
    }

    function pause() external onlyAdmin {
        paused = true;
        emit Paused();
    }

    function unpause() external onlyAdmin {
        paused = false;
        emit Unpaused();
    }

    function emergencyWithdraw() external onlyAdmin {
        uint256 contractBalance = address(this).balance;
        require(contractBalance > 0, "No funds to withdraw");

        (bool success, ) = admin.call{value: contractBalance}("");
        require(success, "Transfer failed");

        paused = true;
        emit EmergencyWithdraw(admin, contractBalance);
    }

    function getStakingBalance(address _user) external view returns (uint256) {
        return stakingBalance[_user];
    }

    function isUserStaking(address _user) external view returns (bool) {
        return isStaking[_user];
    }
}