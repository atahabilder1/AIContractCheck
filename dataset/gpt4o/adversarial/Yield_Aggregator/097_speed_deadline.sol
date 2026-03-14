// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
}

interface IYieldFarm {
    function deposit(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function getReward() external;
    function balanceOf(address account) external view returns (uint256);
}

contract YieldAggregator {
    IERC20 public immutable stakingToken;
    IYieldFarm public immutable yieldFarm;

    mapping(address => uint256) public balances;

    constructor(address _stakingToken, address _yieldFarm) {
        stakingToken = IERC20(_stakingToken);
        yieldFarm = IYieldFarm(_yieldFarm);
    }

    function deposit(uint256 amount) external {
        require(amount > 0, "Amount must be greater than zero");
        stakingToken.transferFrom(msg.sender, address(this), amount);
        stakingToken.approve(address(yieldFarm), amount);
        yieldFarm.deposit(amount);
        balances[msg.sender] += amount;
    }

    function withdraw(uint256 amount) external {
        require(amount > 0, "Amount must be greater than zero");
        require(balances[msg.sender] >= amount, "Insufficient balance");
        
        yieldFarm.withdraw(amount);
        stakingToken.transfer(msg.sender, amount);
        balances[msg.sender] -= amount;
    }

    function claimReward() external {
        yieldFarm.getReward();
        uint256 rewardBalance = stakingToken.balanceOf(address(this)) - totalDeposits();
        stakingToken.transfer(msg.sender, rewardBalance);
    }

    function totalDeposits() public view returns (uint256) {
        return yieldFarm.balanceOf(address(this));
    }
}