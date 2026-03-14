// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IStrategy {
    function deposit(uint256 _amount) external returns (uint256);
    function withdraw(uint256 _amount) external returns (uint256);
    function harvest() external returns (uint256);
    function getBalance() external view returns (uint256);
    function getStrategyBalance() external view returns (uint256);
    function getVaultBalance() external view returns (uint256);
}

interface IVault {
    function deposit(uint256 _amount) external returns (uint256);
    function withdraw(uint256 _amount) external returns (uint256);
    function getBalance() external view returns (uint256);
    function getSharePrice() external view returns (uint256);
}

contract YieldAggregator {
    address public owner;
    address public strategy;
    address public vault;

    constructor(address _strategy, address _vault) {
        owner = msg.sender;
        strategy = _strategy;
        vault = _vault;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    function setStrategy(address _strategy) external onlyOwner {
        strategy = _strategy;
    }

    function setVault(address _vault) external onlyOwner {
        vault = _vault;
    }

    function deposit(uint256 _amount) external {
        IVault(_vault).deposit(_amount);
        IStrategy(_strategy).deposit(_amount);
    }

    function withdraw(uint256 _amount) external {
        IStrategy(_strategy).withdraw(_amount);
        IVault(_vault).withdraw(_amount);
    }

    function harvest() external {
        IStrategy(_strategy).harvest();
    }

    function getVaultBalance() external view returns (uint256) {
        return IVault(_vault).getBalance();
    }

    function getStrategyBalance() external view returns (uint256) {
        return IStrategy(_strategy).getBalance();
    }

    function getStrategyVaultBalance() external view returns (uint256) {
        return IStrategy(_strategy).getVaultBalance();
    }

    function getStrategyStrategyBalance() external view returns (uint256) {
        return IStrategy(_strategy).getStrategyBalance();
    }

    function getVaultSharePrice() external view returns (uint256) {
        return IVault(_vault).getSharePrice();
    }
}