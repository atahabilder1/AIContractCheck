// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MultiStrategyVault is Ownable {
    using SafeERC20 for IERC20;

    struct Strategy {
        address strategyAddress;
        uint256 weight;
    }

    IERC20 public immutable want;
    Strategy[] public strategies;
    uint256 public totalWeight;
    uint256 public performanceFee = 200; // 2% performance fee
    uint256 public constant FEE_DENOMINATOR = 10000;

    event StrategyAdded(address strategy, uint256 weight);
    event StrategyRemoved(address strategy);
    event StrategyWeightUpdated(address strategy, uint256 weight);
    event Harvested(uint256 amount);
    event EmergencyWithdraw(uint256 amount);

    constructor(address _want) {
        want = IERC20(_want);
    }

    function addStrategy(address _strategy, uint256 _weight) external onlyOwner {
        require(_strategy != address(0), "Strategy address cannot be zero");
        require(_weight > 0, "Weight must be greater than zero");
        strategies.push(Strategy({strategyAddress: _strategy, weight: _weight}));
        totalWeight += _weight;
        emit StrategyAdded(_strategy, _weight);
    }

    function removeStrategy(uint256 _index) external onlyOwner {
        require(_index < strategies.length, "Index out of bounds");
        Strategy memory strategy = strategies[_index];
        totalWeight -= strategy.weight;
        strategies[_index] = strategies[strategies.length - 1];
        strategies.pop();
        emit StrategyRemoved(strategy.strategyAddress);
    }

    function updateStrategyWeight(uint256 _index, uint256 _weight) external onlyOwner {
        require(_index < strategies.length, "Index out of bounds");
        require(_weight > 0, "Weight must be greater than zero");
        Strategy storage strategy = strategies[_index];
        totalWeight -= strategy.weight;
        strategy.weight = _weight;
        totalWeight += _weight;
        emit StrategyWeightUpdated(strategy.strategyAddress, _weight);
    }

    function deposit(uint256 _amount) external {
        require(_amount > 0, "Amount must be greater than zero");
        want.safeTransferFrom(msg.sender, address(this), _amount);
        uint256 _balance = want.balanceOf(address(this));
        for (uint256 i = 0; i < strategies.length; i++) {
            uint256 _strategyBalance = (_balance * strategies[i].weight) / totalWeight;
            want.safeTransfer(strategies[i].strategyAddress, _strategyBalance);
        }
    }

    function harvest() external onlyOwner {
        uint256 _before = want.balanceOf(address(this));
        for (uint256 i = 0; i < strategies.length; i++) {
            IStrategy(strategies[i].strategyAddress).harvest();
            uint256 _harvested = IStrategy(strategies[i].strategyAddress).withdrawAll();
            want.safeTransferFrom(strategies[i].strategyAddress, address(this), _harvested);
        }
        uint256 _after = want.balanceOf(address(this));
        uint256 _harvestedAmount = _after - _before;
        uint256 _performanceFee = (_harvestedAmount * performanceFee) / FEE_DENOMINATOR;
        want.safeTransfer(msg.sender, _performanceFee);
        emit Harvested(_harvestedAmount);
    }

    function emergencyWithdraw() external onlyOwner {
        uint256 _amount = want.balanceOf(address(this));
        for (uint256 i = 0; i < strategies.length; i++) {
            IStrategy(strategies[i].strategyAddress).withdrawAll();
            uint256 _strategyBalance = IERC20(want).balanceOf(strategies[i].strategyAddress);
            want.safeTransferFrom(strategies[i].strategyAddress, address(this), _strategyBalance);
        }
        want.safeTransfer(msg.sender, want.balanceOf(address(this)));
        emit EmergencyWithdraw(_amount);
    }

    function setPerformanceFee(uint256 _fee) external onlyOwner {
        require(_fee <= FEE_DENOMINATOR, "Fee must be less than or equal to 100%");
        performanceFee = _fee;
    }
}

interface IStrategy {
    function harvest() external;
    function withdrawAll() external returns (uint256);
}