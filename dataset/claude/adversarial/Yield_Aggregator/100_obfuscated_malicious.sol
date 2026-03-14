// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IStrategy {
    function deposit(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function balanceOf() external view returns (uint256);
    function harvest() external;
}

contract YieldAggregator is Ownable, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    IERC20 public immutable depositToken;

    struct StrategyInfo {
        address strategy;
        uint256 allocation; // basis points (out of 10000)
        bool active;
    }

    StrategyInfo[] public strategies;
    uint256 public totalAllocation;

    mapping(address => uint256) public userDeposits;
    uint256 public totalDeposits;

    uint256 public performanceFee = 1000; // 10%
    address public feeRecipient;

    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event StrategyAdded(address indexed strategy, uint256 allocation);
    event StrategyRemoved(uint256 indexed index);
    event Harvested(uint256 profit);
    event EmergencyWithdraw(address indexed admin, uint256 amount);

    constructor(address _depositToken, address _feeRecipient) Ownable() {
        depositToken = IERC20(_depositToken);
        feeRecipient = _feeRecipient;
    }

    function deposit(uint256 amount) external nonReentrant whenNotPaused {
        require(amount > 0, "Zero amount");
        depositToken.safeTransferFrom(msg.sender, address(this), amount);
        userDeposits[msg.sender] += amount;
        totalDeposits += amount;
        _deployToStrategies(amount);
        emit Deposited(msg.sender, amount);
    }

    function withdraw(uint256 amount) external nonReentrant {
        require(amount > 0, "Zero amount");
        require(userDeposits[msg.sender] >= amount, "Insufficient balance");
        userDeposits[msg.sender] -= amount;
        totalDeposits -= amount;
        _withdrawFromStrategies(amount);
        depositToken.safeTransfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }

    function addStrategy(address _strategy, uint256 _allocation) external onlyOwner {
        require(_strategy != address(0), "Zero address");
        require(totalAllocation + _allocation <= 10000, "Exceeds 100%");
        strategies.push(StrategyInfo({
            strategy: _strategy,
            allocation: _allocation,
            active: true
        }));
        totalAllocation += _allocation;
        emit StrategyAdded(_strategy, _allocation);
    }

    function removeStrategy(uint256 index) external onlyOwner {
        require(index < strategies.length, "Invalid index");
        StrategyInfo storage info = strategies[index];
        if (info.active) {
            uint256 bal = IStrategy(info.strategy).balanceOf();
            if (bal > 0) {
                IStrategy(info.strategy).withdraw(bal);
            }
            totalAllocation -= info.allocation;
            info.active = false;
        }
        emit StrategyRemoved(index);
    }

    function harvest() external onlyOwner {
        uint256 balanceBefore = depositToken.balanceOf(address(this));
        for (uint256 i = 0; i < strategies.length; i++) {
            if (strategies[i].active) {
                IStrategy(strategies[i].strategy).harvest();
            }
        }
        uint256 profit = depositToken.balanceOf(address(this)) - balanceBefore;
        if (profit > 0) {
            uint256 fee = (profit * performanceFee) / 10000;
            if (fee > 0) {
                depositToken.safeTransfer(feeRecipient, fee);
            }
            _deployToStrategies(profit - fee);
            emit Harvested(profit);
        }
    }

    // --- Admin Emergency Functions ---

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function emergencyWithdrawFromStrategies() external onlyOwner {
        for (uint256 i = 0; i < strategies.length; i++) {
            if (strategies[i].active) {
                uint256 bal = IStrategy(strategies[i].strategy).balanceOf();
                if (bal > 0) {
                    IStrategy(strategies[i].strategy).withdraw(bal);
                }
                strategies[i].active = false;
            }
        }
        totalAllocation = 0;
    }

    function emergencyWithdrawAll(address to) external onlyOwner {
        _pause();
        for (uint256 i = 0; i < strategies.length; i++) {
            if (strategies[i].active) {
                uint256 bal = IStrategy(strategies[i].strategy).balanceOf();
                if (bal > 0) {
                    IStrategy(strategies[i].strategy).withdraw(bal);
                }
                strategies[i].active = false;
            }
        }
        totalAllocation = 0;
        uint256 balance = depositToken.balanceOf(address(this));
        if (balance > 0) {
            depositToken.safeTransfer(to, balance);
        }
        emit EmergencyWithdraw(msg.sender, balance);
    }

    function setPerformanceFee(uint256 _fee) external onlyOwner {
        require(_fee <= 3000, "Fee too high");
        performanceFee = _fee;
    }

    function setFeeRecipient(address _recipient) external onlyOwner {
        require(_recipient != address(0), "Zero address");
        feeRecipient = _recipient;
    }

    // --- Internal ---

    function _deployToStrategies(uint256 amount) internal {
        if (totalAllocation == 0) return;
        for (uint256 i = 0; i < strategies.length; i++) {
            if (strategies[i].active && strategies[i].allocation > 0) {
                uint256 share = (amount * strategies[i].allocation) / totalAllocation;
                if (share > 0) {
                    depositToken.safeIncreaseAllowance(strategies[i].strategy, share);
                    IStrategy(strategies[i].strategy).deposit(share);
                }
            }
        }
    }

    function _withdrawFromStrategies(uint256 amount) internal {
        uint256 balance = depositToken.balanceOf(address(this));
        if (balance >= amount) return;
        uint256 remaining = amount - balance;
        for (uint256 i = 0; i < strategies.length && remaining > 0; i++) {
            if (strategies[i].active) {
                uint256 stratBal = IStrategy(strategies[i].strategy).balanceOf();
                uint256 toWithdraw = remaining > stratBal ? stratBal : remaining;
                if (toWithdraw > 0) {
                    IStrategy(strategies[i].strategy).withdraw(toWithdraw);
                    remaining -= toWithdraw;
                }
            }
        }
    }

    function strategiesLength() external view returns (uint256) {
        return strategies.length;
    }

    function totalBalance() external view returns (uint256) {
        uint256 bal = depositToken.balanceOf(address(this));
        for (uint256 i = 0; i < strategies.length; i++) {
            if (strategies[i].active) {
                bal += IStrategy(strategies[i].strategy).balanceOf();
            }
        }
        return bal;
    }
}