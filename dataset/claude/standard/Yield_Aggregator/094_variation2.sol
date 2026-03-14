// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface IStrategy {
    function deposit(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function withdrawAll() external returns (uint256);
    function balanceOf() external view returns (uint256);
    function currentAPY() external view returns (uint256);
    function want() external view returns (address);
}

contract YieldAggregator is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable depositToken;

    struct StrategyInfo {
        address strategy;
        bool active;
    }

    StrategyInfo[] public strategies;
    mapping(address => bool) public isStrategy;
    mapping(address => bool) public keepers;

    uint256 public activeStrategyIndex;
    uint256 public totalDeposited;
    uint256 public minAPYDifference = 50; // 0.5% in basis points (1 = 0.01%)

    mapping(address => uint256) public userDeposits;
    mapping(address => uint256) public userShares;
    uint256 public totalShares;

    uint256 public lastRotation;
    uint256 public rotationCooldown = 1 hours;

    event Deposited(address indexed user, uint256 amount, uint256 shares);
    event Withdrawn(address indexed user, uint256 amount, uint256 shares);
    event StrategyAdded(address indexed strategy, uint256 index);
    event StrategyRemoved(uint256 index);
    event StrategyRotated(uint256 fromIndex, uint256 toIndex, uint256 newAPY);
    event KeeperUpdated(address indexed keeper, bool status);

    modifier onlyKeeper() {
        require(keepers[msg.sender] || msg.sender == owner(), "not keeper");
        _;
    }

    constructor(address _depositToken) Ownable(msg.sender) {
        depositToken = IERC20(_depositToken);
    }

    function addStrategy(address _strategy) external onlyOwner {
        require(!isStrategy[_strategy], "already added");
        require(IStrategy(_strategy).want() == address(depositToken), "wrong token");

        strategies.push(StrategyInfo({strategy: _strategy, active: true}));
        isStrategy[_strategy] = true;

        depositToken.forceApprove(_strategy, type(uint256).max);

        emit StrategyAdded(_strategy, strategies.length - 1);
    }

    function removeStrategy(uint256 _index) external onlyOwner {
        require(_index < strategies.length, "invalid index");
        require(_index != activeStrategyIndex || strategies.length == 1, "withdraw first");

        address strat = strategies[_index].strategy;
        strategies[_index].active = false;
        isStrategy[strat] = false;

        depositToken.forceApprove(strat, 0);

        emit StrategyRemoved(_index);
    }

    function setKeeper(address _keeper, bool _status) external onlyOwner {
        keepers[_keeper] = _status;
        emit KeeperUpdated(_keeper, _status);
    }

    function setMinAPYDifference(uint256 _minDiff) external onlyOwner {
        minAPYDifference = _minDiff;
    }

    function setRotationCooldown(uint256 _cooldown) external onlyOwner {
        rotationCooldown = _cooldown;
    }

    function deposit(uint256 _amount) external nonReentrant {
        require(_amount > 0, "zero amount");
        require(strategies.length > 0, "no strategies");

        uint256 totalBefore = totalBalance();
        depositToken.safeTransferFrom(msg.sender, address(this), _amount);

        uint256 shares;
        if (totalShares == 0 || totalBefore == 0) {
            shares = _amount;
        } else {
            shares = (_amount * totalShares) / totalBefore;
        }

        userShares[msg.sender] += shares;
        totalShares += shares;
        totalDeposited += _amount;

        _depositToActiveStrategy(_amount);

        emit Deposited(msg.sender, _amount, shares);
    }

    function withdraw(uint256 _shares) external nonReentrant {
        require(_shares > 0 && _shares <= userShares[msg.sender], "invalid shares");

        uint256 totalBal = totalBalance();
        uint256 amount = (_shares * totalBal) / totalShares;

        userShares[msg.sender] -= _shares;
        totalShares -= _shares;

        uint256 localBal = depositToken.balanceOf(address(this));
        if (localBal < amount) {
            uint256 needed = amount - localBal;
            IStrategy(strategies[activeStrategyIndex].strategy).withdraw(needed);
            localBal = depositToken.balanceOf(address(this));
            if (localBal < amount) {
                amount = localBal;
            }
        }

        if (amount > totalDeposited) {
            totalDeposited = 0;
        } else {
            totalDeposited -= amount;
        }

        depositToken.safeTransfer(msg.sender, amount);

        emit Withdrawn(msg.sender, amount, _shares);
    }

    function rotate() external onlyKeeper {
        require(strategies.length > 1, "need multiple strategies");
        require(block.timestamp >= lastRotation + rotationCooldown, "cooldown active");

        (uint256 bestIndex, uint256 bestAPY) = findBestStrategy();
        uint256 currentAPY = IStrategy(strategies[activeStrategyIndex].strategy).currentAPY();

        require(
            bestIndex != activeStrategyIndex && bestAPY > currentAPY + minAPYDifference,
            "rotation not beneficial"
        );

        uint256 oldIndex = activeStrategyIndex;

        uint256 recovered = IStrategy(strategies[oldIndex].strategy).withdrawAll();

        activeStrategyIndex = bestIndex;
        lastRotation = block.timestamp;

        if (recovered > 0) {
            _depositToActiveStrategy(recovered);
        }

        emit StrategyRotated(oldIndex, bestIndex, bestAPY);
    }

    function findBestStrategy() public view returns (uint256 bestIndex, uint256 bestAPY) {
        bestAPY = 0;
        bestIndex = activeStrategyIndex;

        for (uint256 i = 0; i < strategies.length; i++) {
            if (!strategies[i].active) continue;
            uint256 apy = IStrategy(strategies[i].strategy).currentAPY();
            if (apy > bestAPY) {
                bestAPY = apy;
                bestIndex = i;
            }
        }
    }

    function shouldRotate() external view returns (bool, uint256) {
        if (strategies.length <= 1) return (false, activeStrategyIndex);
        if (block.timestamp < lastRotation + rotationCooldown) return (false, activeStrategyIndex);

        (uint256 bestIndex, uint256 bestAPY) = findBestStrategy();
        uint256 currentAPY = IStrategy(strategies[activeStrategyIndex].strategy).currentAPY();

        if (bestIndex != activeStrategyIndex && bestAPY > currentAPY + minAPYDifference) {
            return (true, bestIndex);
        }
        return (false, activeStrategyIndex);
    }

    function totalBalance() public view returns (uint256) {
        uint256 local = depositToken.balanceOf(address(this));
        if (strategies.length == 0) return local;
        uint256 stratBal = IStrategy(strategies[activeStrategyIndex].strategy).balanceOf();
        return local + stratBal;
    }

    function shareValue(uint256 _shares) external view returns (uint256) {
        if (totalShares == 0) return 0;
        return (_shares * totalBalance()) / totalShares;
    }

    function strategyCount() external view returns (uint256) {
        return strategies.length;
    }

    function _depositToActiveStrategy(uint256 _amount) internal {
        IStrategy(strategies[activeStrategyIndex].strategy).deposit(_amount);
    }

    function rescueTokens(address _token) external onlyOwner {
        require(_token != address(depositToken), "cannot rescue deposit token");
        uint256 bal = IERC20(_token).balanceOf(address(this));
        IERC20(_token).safeTransfer(owner(), bal);
    }
}