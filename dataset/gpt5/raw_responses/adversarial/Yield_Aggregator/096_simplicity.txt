// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    function transfer(address to, uint256 value) external returns (bool);
    function approve(address spender, uint256 value) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

interface IStrategy {
    function deposit(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function balanceOf() external view returns (uint256);
}

contract YieldAggregator {
    IERC20 public immutable asset;
    IStrategy public immutable strategy;

    uint256 public totalShares;
    mapping(address => uint256) public shares;

    constructor(IERC20 _asset, IStrategy _strategy) {
        asset = _asset;
        strategy = _strategy;
        _asset.approve(address(_strategy), type(uint256).max);
    }

    function totalAssets() public view returns (uint256) {
        return asset.balanceOf(address(this)) + strategy.balanceOf();
    }

    function deposit(uint256 amount) external returns (uint256 share) {
        require(amount > 0, "amount=0");
        uint256 assetsBefore = totalAssets();
        require(asset.transferFrom(msg.sender, address(this), amount), "transferFrom failed");

        if (totalShares == 0 || assetsBefore == 0) {
            share = amount;
        } else {
            share = amount * totalShares / assetsBefore;
        }

        shares[msg.sender] += share;
        totalShares += share;

        uint256 bal = asset.balanceOf(address(this));
        if (bal > 0) {
            strategy.deposit(bal);
        }
    }

    function withdraw(uint256 share) external returns (uint256 amountOut) {
        require(share > 0, "share=0");
        uint256 userShares = shares[msg.sender];
        require(share <= userShares, "insufficient shares");

        uint256 assets = totalAssets();
        amountOut = assets * share / totalShares;

        shares[msg.sender] = userShares - share;
        totalShares -= share;

        uint256 bal = asset.balanceOf(address(this));
        if (bal < amountOut) {
            strategy.withdraw(amountOut - bal);
        }

        require(asset.transfer(msg.sender, amountOut), "transfer failed");
    }
}