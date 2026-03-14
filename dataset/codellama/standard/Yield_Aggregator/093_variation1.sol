// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Vault {
    address public pool;
    address public tokenA;
    address public tokenB;
    uint256 public rewardPerShare;
    uint256 public totalSupply;

    constructor(address _pool, address _tokenA, address _tokenB) {
        pool = _pool;
        tokenA = _tokenA;
        tokenB = _tokenB;
        rewardPerShare = 0;
        totalSupply = 0;
    }

    function addLiquidity(uint256 _amount) public {
        require(msg.sender == pool, "Only the pool can add liquidity");
        require(_amount > 0, "Amount must be greater than 0");

        uint256 _tokenAAmount = _amount.mul(10**18).div(getTokenPrice(tokenA));
        uint256 _tokenBAmount = _amount.mul(10**18).div(getTokenPrice(tokenB));

        // Add liquidity to the pool
        pool.addLiquidity(tokenA, _tokenAAmount, tokenB, _tokenBAmount);

        // Update rewardPerShare and totalSupply
        rewardPerShare = getRewardPerShare();
        totalSupply = getTotalSupply();
    }

    function getRewardPerShare() public view returns (uint256) {
        return pool.getRewardPerShare(tokenA, tokenB);
    }

    function getTotalSupply() public view returns (uint256) {
        return pool.getTotalSupply(tokenA, tokenB);
    }

    function compoundRewards() public {
        require(msg.sender == pool, "Only the pool can compound rewards");

        // Get the current reward per share
        uint256 _rewardPerShare = getRewardPerShare();

        // Calculate the reward for the current position
        uint256 _reward = _rewardPerShare.mul(totalSupply).div(10**18);

        // Transfer the reward to the pool
        pool.transfer(tokenA, _reward);

        // Update rewardPerShare and totalSupply
        rewardPerShare = getRewardPerShare();
        totalSupply = getTotalSupply();
    }
}