// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

interface IStrategy {
    function deposit(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function harvest() external returns (uint256);
    function balanceOf() external view returns (uint256);
    function want() external view returns (address);
}

contract YieldAggregator {
    IERC20 public immutable token;
    address public owner;
    address public activeStrategy;

    mapping(address => uint256) public shares;
    uint256 public totalShares;

    address[] public strategies;
    mapping(address => bool) public approvedStrategies;

    event Deposit(address indexed user, uint256 amount, uint256 shares);
    event Withdraw(address indexed user, uint256 amount, uint256 shares);
    event StrategyAdded(address indexed strategy);
    event StrategyRemoved(address indexed strategy);
    event StrategyChanged(address indexed oldStrategy, address indexed newStrategy);
    event Harvested(uint256 profit);

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    constructor(address _token) {
        token = IERC20(_token);
        owner = msg.sender;
    }

    function deposit(uint256 amount) external {
        require(amount > 0, "zero amount");

        uint256 pool = totalBalance();
        token.transferFrom(msg.sender, address(this), amount);

        uint256 newShares;
        if (totalShares == 0 || pool == 0) {
            newShares = amount;
        } else {
            newShares = (amount * totalShares) / pool;
        }

        shares[msg.sender] += newShares;
        totalShares += newShares;

        _deployToStrategy();

        emit Deposit(msg.sender, amount, newShares);
    }

    function withdraw(uint256 _shares) external {
        require(_shares > 0 && _shares <= shares[msg.sender], "invalid shares");

        uint256 amount = (_shares * totalBalance()) / totalShares;

        shares[msg.sender] -= _shares;
        totalShares -= _shares;

        uint256 localBalance = token.balanceOf(address(this));
        if (localBalance < amount) {
            uint256 deficit = amount - localBalance;
            IStrategy(activeStrategy).withdraw(deficit);
        }

        token.transfer(msg.sender, amount);

        emit Withdraw(msg.sender, amount, _shares);
    }

    function totalBalance() public view returns (uint256) {
        uint256 strategyBalance = activeStrategy != address(0)
            ? IStrategy(activeStrategy).balanceOf()
            : 0;
        return token.balanceOf(address(this)) + strategyBalance;
    }

    function pricePerShare() external view returns (uint256) {
        if (totalShares == 0) return 1e18;
        return (totalBalance() * 1e18) / totalShares;
    }

    function addStrategy(address _strategy) external onlyOwner {
        require(!approvedStrategies[_strategy], "already added");
        require(IStrategy(_strategy).want() == address(token), "wrong token");
        approvedStrategies[_strategy] = true;
        strategies.push(_strategy);
        emit StrategyAdded(_strategy);
    }

    function setActiveStrategy(address _strategy) external onlyOwner {
        require(approvedStrategies[_strategy], "not approved");

        address old = activeStrategy;
        if (old != address(0)) {
            uint256 bal = IStrategy(old).balanceOf();
            if (bal > 0) {
                IStrategy(old).withdraw(bal);
            }
        }

        activeStrategy = _strategy;
        _deployToStrategy();

        emit StrategyChanged(old, _strategy);
    }

    function harvest() external {
        require(activeStrategy != address(0), "no strategy");
        uint256 profit = IStrategy(activeStrategy).harvest();
        emit Harvested(profit);
    }

    function _deployToStrategy() internal {
        if (activeStrategy == address(0)) return;
        uint256 available = token.balanceOf(address(this));
        if (available > 0) {
            token.approve(activeStrategy, available);
            IStrategy(activeStrategy).deposit(available);
        }
    }

    function removeStrategy(address _strategy) external onlyOwner {
        require(approvedStrategies[_strategy], "not approved");
        require(_strategy != activeStrategy, "strategy is active");
        approvedStrategies[_strategy] = false;
        emit StrategyRemoved(_strategy);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "zero address");
        owner = newOwner;
    }
}