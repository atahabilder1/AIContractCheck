// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts@4.6.0/token/ERC20/IERC20.sol";

contract StakingContract {
    IERC20 public stakingToken;
    uint256 public totalSupply;
    uint256 public fixedAPY = 10; // 10% APY

    constructor(IERC20 _stakingToken) {
        stakingToken = _stakingToken;
    }

    function stake(uint256 amount) external {
        require(amount > 0, "Stake amount must be greater than zero");
        stakingToken.transferFrom(msg.sender, address(this), amount);
        totalSupply += amount;
    }

    function withdraw() external {
        uint256 userBalance = stakingToken.balanceOf(address(this));
        require(userBalance > 0, "No tokens to withdraw");
        uint256 rewards = (userBalance * fixedAPY * block.timestamp) / (totalSupply * 100 * 31536000); // Calculate rewards based on total value locked and APY
        stakingToken.transfer(msg.sender, userBalance + rewards);
        totalSupply -= userBalance;
    }
}