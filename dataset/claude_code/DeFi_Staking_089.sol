// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Staking with admin emergency functions
contract EmergencyStaking {
    address public token;
    address public admin;
    bool public paused;
    uint256 public totalStaked;

    mapping(address => uint256) public staked;
    mapping(address => uint256) public rewards;

    constructor(address _token) {
        token = _token;
        admin = msg.sender;
    }

    modifier onlyAdmin() { require(msg.sender == admin); _; }
    modifier whenNotPaused() { require(!paused); _; }

    function stake(uint256 amount) external whenNotPaused {
        staked[msg.sender] += amount;
        totalStaked += amount;
        IERC20(token).transferFrom(msg.sender, address(this), amount);
    }

    function withdraw(uint256 amount) external whenNotPaused {
        staked[msg.sender] -= amount;
        totalStaked -= amount;
        IERC20(token).transfer(msg.sender, amount);
    }

    // Emergency functions
    function emergencyPause() external onlyAdmin { paused = true; }
    function emergencyUnpause() external onlyAdmin { paused = false; }

    function emergencyWithdrawAll() external onlyAdmin {
        uint256 balance = IERC20(token).balanceOf(address(this));
        IERC20(token).transfer(admin, balance);
    }

    function emergencyWithdrawUser(address user) external onlyAdmin {
        uint256 amount = staked[user];
        staked[user] = 0;
        totalStaked -= amount;
        IERC20(token).transfer(admin, amount);
    }
}

interface IERC20 {
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
}
