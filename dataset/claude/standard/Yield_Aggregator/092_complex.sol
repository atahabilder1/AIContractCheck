// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface IStrategy {
    function deposit(uint256 amount) external;
    function withdraw(uint256 amount) external returns (uint256);
    function harvest() external returns (uint256);
    function totalAssets() external view returns (uint256);
    function want() external view returns (address);
    function emergencyWithdraw() external returns (uint256);
}

contract MultiStrategyYieldVault is ERC20, ReentrancyGuard {
    using SafeERC20 for IERC20;

    struct StrategyInfo {
        bool active;
        uint256 allocationWeight;
        uint256 totalDebt;
        uint256 totalGain;
        uint256 totalLoss;
        uint256 lastHarvest;
    }

    IERC20 public immutable token;
    address public governance;
    address public pendingGovernance;
    address public treasury;

    uint256 public performanceFeeBps = 1000; // 10%
    uint256 public managementFeeBps = 200;   // 2%
    uint256 public constant MAX_BPS = 10000;
    uint256 public constant MAX_PERFORMANCE_FEE = 3000;
    uint256 public constant MAX_STRATEGIES = 20;

    uint256 public totalDebt;
    uint256 public totalAllocWeight;
    uint256 public lastReport;
    bool public emergencyShutdown;

    address[] public strategies;
    mapping(address => StrategyInfo) public strategyInfo;

    event StrategyAdded(address indexed strategy, uint256 weight);
    event StrategyRemoved(address indexed strategy);
    event StrategyWeightUpdated(address indexed strategy, uint256 newWeight);
    event Harvested(address indexed strategy, uint256 profit, uint256 loss, uint256 fee);
    event Deposited(address indexed user, uint256 amount, uint256 shares);
    event Withdrawn(address indexed user, uint256 amount, uint256 shares);
    event EmergencyShutdown(bool active);

    modifier onlyGovernance() {
        require(msg.sender == governance, "!governance");
        _;
    }

    constructor(
        address _token,
        address _treasury,
        string memory _name,
        string memory _symbol
    ) ERC20(_name, _symbol) {
        token = IERC20(_token);
        governance = msg.sender;
        treasury = _treasury;
        lastReport = block.timestamp;
    }

    function totalAssets() public view returns (uint256) {
        return token.balanceOf(address(this)) + totalDebt;
    }

    function pricePerShare() public view returns (uint256) {
        uint256 supply = totalSupply();
        if (supply == 0) return 10 ** decimals();
        return (totalAssets() * (10 ** decimals())) / supply;
    }

    function deposit(uint256 _amount) external nonReentrant returns (uint256 shares) {
        require(!emergencyShutdown, "shutdown");
        require(_amount > 0, "zero amount");

        uint256 pool = totalAssets();
        token.safeTransferFrom(msg.sender, address(this), _amount);

        if (totalSupply() == 0) {
            shares = _amount;
        } else {
            shares = (_amount * totalSupply()) / pool;
        }
        require(shares > 0, "zero shares");

        _mint(msg.sender, shares);
        emit Deposited(msg.sender, _amount, shares);
    }

    function withdraw(uint256 _shares) external nonReentrant returns (uint256 amount) {
        require(_shares > 0, "zero shares");
        require(_shares <= balanceOf(msg.sender), "insufficient shares");

        amount = (_shares * totalAssets()) / totalSupply();
        _burn(msg.sender, _shares);

        uint256 vaultBalance = token.balanceOf(address(this));
        if (amount > vaultBalance) {
            uint256 deficit = amount - vaultBalance;
            _withdrawFromStrategies(deficit);
            uint256 newBalance = token.balanceOf(address(this));
            if (newBalance < amount) {
                amount = newBalance;
            }
        }

        token.safeTransfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount, _shares);
    }

    function _withdrawFromStrategies(uint256 _needed) internal {
        for (uint256 i = 0; i < strategies.length && _needed > 0; i++) {
            address strat = strategies[i];
            StrategyInfo storage info = strategyInfo[strat];
            if (!info.active) continue;

            uint256 stratAssets = IStrategy(strat).totalAssets();
            uint256 toWithdraw = _needed > stratAssets ? stratAssets : _needed;
            if (toWithdraw == 0) continue;

            uint256 withdrawn = IStrategy(strat).withdraw(toWithdraw);
            uint256 debtReduction = withdrawn > info.totalDebt ? info.totalDebt : withdrawn;
            info.totalDebt -= debtReduction;
            totalDebt -= debtReduction;
            _needed -= withdrawn > _needed ? _needed : withdrawn;
        }
    }

    function addStrategy(address _strategy, uint256 _weight) external onlyGovernance {
        require(!strategyInfo[_strategy].active, "already active");
        require(IStrategy(_strategy).want() == address(token), "wrong token");
        require(strategies.length < MAX_STRATEGIES, "max strategies");
        require(_weight > 0, "zero weight");

        strategyInfo[_strategy] = StrategyInfo({
            active: true,
            allocationWeight: _weight,
            totalDebt: 0,
            totalGain: 0,
            totalLoss: 0,
            lastHarvest: block.timestamp
        });

        strategies.push(_strategy);
        totalAllocWeight += _weight;
        emit StrategyAdded(_strategy, _weight);
    }

    function removeStrategy(address _strategy) external onlyGovernance {
        StrategyInfo storage info = strategyInfo[_strategy];
        require(info.active, "not active");

        if (info.totalDebt > 0) {
            uint256 withdrawn = IStrategy(_strategy).emergencyWithdraw();
            uint256 debtReduction = withdrawn > info.totalDebt ? info.totalDebt : withdrawn;
            info.totalDebt -= debtReduction;
            totalDebt -= debtReduction;
        }

        totalAllocWeight -= info.allocationWeight;
        info.active = false;
        info.allocationWeight = 0;

        for (uint256 i = 0; i < strategies.length; i++) {
            if (strategies[i] == _strategy) {
                strategies[i] = strategies[strategies.length - 1];
                strategies.pop();
                break;
            }
        }

        emit StrategyRemoved(_strategy);
    }

    function updateStrategyWeight(address _strategy, uint256 _newWeight) external onlyGovernance {
        StrategyInfo storage info = strategyInfo[_strategy];
        require(info.active, "not active");

        totalAllocWeight = totalAllocWeight - info.allocationWeight + _newWeight;
        info.allocationWeight = _newWeight;
        emit StrategyWeightUpdated(_strategy, _newWeight);
    }

    function harvest(address _strategy) external nonReentrant {
        StrategyInfo storage info = strategyInfo[_strategy];
        require(info.active, "not active");

        uint256 profit = IStrategy(_strategy).harvest();

        uint256 fee = 0;
        if (profit > 0) {
            fee = (profit * performanceFeeBps) / MAX_BPS;
            if (fee > 0) {
                uint256 feeShares = totalSupply() > 0
                    ? (fee * totalSupply()) / (totalAssets() - fee)
                    : fee;
                if (feeShares > 0) {
                    _mint(treasury, feeShares);
                }
            }
            info.totalGain += profit;
            info.totalDebt += profit - fee;
            totalDebt += profit - fee;
        }

        info.lastHarvest = block.timestamp;
        lastReport = block.timestamp;
        emit Harvested(_strategy, profit, 0, fee);
    }

    function allocate() external onlyGovernance {
        require(!emergencyShutdown, "shutdown");
        require(totalAllocWeight > 0, "no weights");

        uint256 available = token.balanceOf(address(this));
        if (available == 0) return;

        for (uint256 i = 0; i < strategies.length; i++) {
            address strat = strategies[i];
            StrategyInfo storage info = strategyInfo[strat];
            if (!info.active || info.allocationWeight == 0) continue;

            uint256 allocation = (available * info.allocationWeight) / totalAllocWeight;
            if (allocation == 0) continue;

            token.safeTransfer(strat, allocation);
            IStrategy(strat).deposit(allocation);
            info.totalDebt += allocation;
            totalDebt += allocation;
        }
    }

    function setEmergencyShutdown(bool _active) external onlyGovernance {
        emergencyShutdown = _active;
        if (_active) {
            for (uint256 i = 0; i < strategies.length; i++) {
                address strat = strategies[i];
                StrategyInfo storage info = strategyInfo[strat];
                if (!info.active || info.totalDebt == 0) continue;

                uint256 withdrawn = IStrategy(strat).emergencyWithdraw();
                uint256 debtReduction = withdrawn > info.totalDebt ? info.totalDebt : withdrawn;
                info.totalDebt -= debtReduction;
                totalDebt -= debtReduction;
            }
        }
        emit EmergencyShutdown(_active);
    }

    function setPerformanceFee(uint256 _fee) external onlyGovernance {
        require(_fee <= MAX_PERFORMANCE_FEE, "fee too high");
        performanceFeeBps = _fee;
    }

    function setManagementFee(uint256 _fee) external onlyGovernance {
        require(_fee <= MAX_BPS, "fee too high");
        managementFeeBps = _fee;
    }

    function setTreasury(address _treasury) external onlyGovernance {
        require(_treasury != address(0), "zero address");
        treasury = _treasury;
    }

    function setPendingGovernance(address _governance) external onlyGovernance {
        pendingGovernance = _governance;
    }

    function acceptGovernance() external {
        require(msg.sender == pendingGovernance, "!pending");
        governance = msg.sender;
        pendingGovernance = address(0);
    }

    function getStrategies() external view returns (address[] memory) {
        return strategies;
    }

    function getStrategyCount() external view returns (uint256) {
        return strategies.length;
    }
}