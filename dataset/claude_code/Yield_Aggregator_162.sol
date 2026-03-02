// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Basic Yield Aggregator / Vault
contract YieldVault {
    address public asset;
    address public strategy;
    address public owner;
    uint256 public totalShares;
    uint256 public totalAssets;

    mapping(address => uint256) public shares;

    event Deposit(address indexed user, uint256 assets, uint256 shares);
    event Withdraw(address indexed user, uint256 assets, uint256 shares);
    event Harvest(uint256 profit);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor(address _asset) {
        asset = _asset;
        owner = msg.sender;
    }

    function deposit(uint256 assets) external returns (uint256 sharesToMint) {
        require(assets > 0, "Must deposit > 0");

        if (totalShares == 0) {
            sharesToMint = assets;
        } else {
            sharesToMint = assets * totalShares / totalAssets;
        }

        shares[msg.sender] += sharesToMint;
        totalShares += sharesToMint;
        totalAssets += assets;

        IERC20(asset).transferFrom(msg.sender, address(this), assets);

        emit Deposit(msg.sender, assets, sharesToMint);
    }

    function withdraw(uint256 sharesToBurn) external returns (uint256 assetsToReturn) {
        require(shares[msg.sender] >= sharesToBurn, "Insufficient shares");

        assetsToReturn = sharesToBurn * totalAssets / totalShares;

        shares[msg.sender] -= sharesToBurn;
        totalShares -= sharesToBurn;
        totalAssets -= assetsToReturn;

        IERC20(asset).transfer(msg.sender, assetsToReturn);

        emit Withdraw(msg.sender, assetsToReturn, sharesToBurn);
    }

    function harvest() external onlyOwner {
        require(strategy != address(0), "No strategy set");

        uint256 balanceBefore = IERC20(asset).balanceOf(address(this));
        IStrategy(strategy).harvest();
        uint256 balanceAfter = IERC20(asset).balanceOf(address(this));

        uint256 profit = balanceAfter - balanceBefore;
        totalAssets += profit;

        emit Harvest(profit);
    }

    function setStrategy(address _strategy) external onlyOwner {
        strategy = _strategy;
    }

    function investInStrategy(uint256 amount) external onlyOwner {
        require(strategy != address(0), "No strategy set");
        IERC20(asset).transfer(strategy, amount);
        IStrategy(strategy).deposit(amount);
    }

    function withdrawFromStrategy(uint256 amount) external onlyOwner {
        require(strategy != address(0), "No strategy set");
        IStrategy(strategy).withdraw(amount);
    }

    function getPricePerShare() external view returns (uint256) {
        if (totalShares == 0) return 1e18;
        return totalAssets * 1e18 / totalShares;
    }

    function balanceOf(address user) external view returns (uint256) {
        return shares[user];
    }

    function convertToAssets(uint256 _shares) external view returns (uint256) {
        if (totalShares == 0) return _shares;
        return _shares * totalAssets / totalShares;
    }

    function convertToShares(uint256 assets) external view returns (uint256) {
        if (totalShares == 0) return assets;
        return assets * totalShares / totalAssets;
    }
}

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

interface IStrategy {
    function deposit(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function harvest() external;
}
