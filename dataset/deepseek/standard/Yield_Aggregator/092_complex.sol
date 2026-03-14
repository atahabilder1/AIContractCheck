// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

interface IStrategy {
    function want() external view returns (address);
    function deposit() external;
    function withdraw(uint256) external;
    function withdrawAll() external;
    function balanceOf() external view returns (uint256);
    function getReward() external;
    function balanceOfPool() external view returns (uint256);
}

contract MultiStrategyVault is Ownable {
    using SafeMath for uint256;

    IERC20 public immutable want;
    IStrategy[] public strategies;
    uint256 public withdrawalFee = 10; // 10% withdrawal fee
    uint256 public performanceFee = 20; // 20% performance fee

    constructor(address _want, IStrategy[] memory _strategies) {
        require(_want != address(0), "Invalid want address");
        want = IERC20(_want);
        for (uint256 i = 0; i < _strategies.length; i++) {
            strategies.push(_strategies[i]);
        }
    }

    function setWithdrawalFee(uint256 _withdrawalFee) external onlyOwner {
        require(_withdrawalFee <= 100, "Fee must be less than or equal to 100%");
        withdrawalFee = _withdrawalFee;
    }

    function setPerformanceFee(uint256 _performanceFee) external onlyOwner {
        require(_performanceFee <= 100, "Fee must be less than or equal to 100%");
        performanceFee = _performanceFee;
    }

    function deposit() external {
        uint256 balance = want.balanceOf(address(this));
        for (uint256 i = 0; i < strategies.length; i++) {
            want.approve(address(strategies[i]), balance);
            strategies[i].deposit();
        }
    }

    function withdraw(uint256 _amount) external {
        require(_amount > 0, "Withdraw amount must be greater than zero");
        uint256 balance = want.balanceOf(address(this));
        if (balance < _amount) {
            _amount = balance;
        }
        uint256 fee = _amount.mul(withdrawalFee).div(100);
        uint256 amountAfterFee = _amount.sub(fee);
        for (uint256 i = 0; i < strategies.length; i++) {
            uint256 strategyBalance = strategies[i].balanceOfPool();
            if (strategyBalance > 0) {
                uint256 withdrawAmount = strategyBalance.mul(_amount).div(balance);
                strategies[i].withdraw(withdrawAmount);
            }
        }
        want.transfer(msg.sender, amountAfterFee);
        want.transfer(owner(), fee);
    }

    function harvest() external {
        for (uint256 i = 0; i < strategies.length; i++) {
            strategies[i].getReward();
        }
        uint256 balanceBefore = want.balanceOf(address(this));
        for (uint256 i = 0; i < strategies.length; i++) {
            uint256 reward = strategies[i].balanceOf() - strategies[i].balanceOfPool();
            if (reward > 0) {
                want.approve(address(strategies[i]), reward);
                strategies[i].deposit();
            }
        }
        uint256 balanceAfter = want.balanceOf(address(this));
        uint256 profit = balanceAfter.sub(balanceBefore);
        if (profit > 0) {
            uint256 fee = profit.mul(performanceFee).div(100);
            want.transfer(owner(), fee);
        }
    }

    function emergencyWithdraw() external onlyOwner {
        for (uint256 i = 0; i < strategies.length; i++) {
            strategies[i].withdrawAll();
        }
        uint256 balance = want.balanceOf(address(this));
        want.transfer(owner(), balance);
    }

    function getTotalValue() external view returns (uint256) {
        uint256 totalValue = 0;
        for (uint256 i = 0; i < strategies.length; i++) {
            totalValue = totalValue.add(strategies[i].balanceOfPool());
        }
        return totalValue;
    }
}