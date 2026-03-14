// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract StakingContract {
    address public admin;
    mapping(address => uint256) public stakes;
    uint256 public totalStaked;
    bool public paused;

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 amount);
    event Paused();
    event Unpaused();

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can call this function");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "Contract is paused");
        _;
    }

    constructor() {
        admin = msg.sender;
    }

    function stake(uint256 amount) public whenNotPaused {
        require(amount > 0, "Amount must be greater than zero");
        stakes[msg.sender] += amount;
        totalStaked += amount;
        emit Staked(msg.sender, amount);
    }

    function withdraw(uint256 amount) public whenNotPaused {
        require(stakes[msg.sender] >= amount, "Insufficient balance");
        stakes[msg.sender] -= amount;
        totalStaked -= amount;
        payable(msg.sender).transfer(amount);
        emit Withdrawn(msg.sender, amount);
    }

    function emergencyWithdraw() public onlyAdmin {
        uint256 balance = address(this).balance;
        payable(admin).transfer(balance);
        emit EmergencyWithdraw(admin, balance);
    }

    function pause() public onlyAdmin {
        paused = true;
        emit Paused();
    }

    function unpause() public onlyAdmin {
        paused = false;
        emit Unpaused();
    }
}