// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IStrategy {
    function deposit(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function harvest() external returns (uint256);
    function balanceOf() external view returns (uint256);
    function want() external view returns (address);
    function apr() external view returns (uint256);
}

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract YieldAggregator {
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    IERC20 public immutable depositToken;
    address public owner;
    address public pendingOwner;

    struct StrategyInfo {
        address strategy;
        uint256 allocPoints;
        uint256 totalDeposited;
        bool active;
    }

    StrategyInfo[] public strategies;
    mapping(address => bool) public strategyExists;

    uint256 public totalAllocPoints;
    uint256 public performanceFee; // basis points (max 2000 = 20%)
    uint256 public withdrawalFee; // basis points (max 100 = 1%)
    address public feeRecipient;

    uint256 public lastHarvestTimestamp;
    uint256 public constant MAX_PERFORMANCE_FEE = 2000;
    uint256 public constant MAX_WITHDRAWAL_FEE = 100;
    uint256 public constant BASIS_POINTS = 10000;

    bool private locked;

    event Deposit(address indexed user, uint256 amount, uint256 shares);
    event Withdraw(address indexed user, uint256 amount, uint256 shares);
    event StrategyAdded(address indexed strategy, uint256 allocPoints);
    event StrategyRemoved(address indexed strategy);
    event StrategyUpdated(address indexed strategy, uint256 allocPoints);
    event Harvest(address indexed caller, uint256 profit, uint256 fee);
    event Rebalance(address indexed caller);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier nonReentrant() {
        require(!locked, "Reentrant call");
        locked = true;
        _;
        locked = false;
    }

    constructor(
        address _depositToken,
        string memory _name,
        string memory _symbol,
        address _feeRecipient,
        uint256 _performanceFee,
        uint256 _withdrawalFee
    ) {
        require(_depositToken != address(0), "Zero address");
        require(_feeRecipient != address(0), "Zero fee recipient");
        require(_performanceFee <= MAX_PERFORMANCE_FEE, "Fee too high");
        require(_withdrawalFee <= MAX_WITHDRAWAL_FEE, "Fee too high");

        depositToken = IERC20(_depositToken);
        name = _name;
        symbol = _symbol;
        owner = msg.sender;
        feeRecipient = _feeRecipient;
        performanceFee = _performanceFee;
        withdrawalFee = _withdrawalFee;
    }

    // ─── ERC20 functions ───

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 currentAllowance = allowance[from][msg.sender];
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "Allowance exceeded");
            allowance[from][msg.sender] = currentAllowance - amount;
        }
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(from != address(0), "From zero address");
        require(to != address(0), "To zero address");
        require(balanceOf[from] >= amount, "Insufficient balance");

        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
    }

    function _mint(address to, uint256 amount) internal {
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        require(balanceOf[from] >= amount, "Insufficient balance");
        balanceOf[from] -= amount;
        totalSupply -= amount;
        emit Transfer(from, address(0), amount);
    }

    // ─── Core vault functions ───

    function deposit(uint256 amount) external nonReentrant {
        require(amount > 0, "Zero amount");

        uint256 totalBefore = totalAssets();
        require(
            depositToken.transferFrom(msg.sender, address(this), amount),
            "Transfer failed"
        );

        uint256 shares;
        if (totalSupply == 0 || totalBefore == 0) {
            shares = amount;
        } else {
            shares = (amount * totalSupply) / totalBefore;
        }

        _mint(msg.sender, shares);
        emit Deposit(msg.sender, amount, shares);
    }

    function withdraw(uint256 shares) external nonReentrant {
        require(shares > 0, "Zero shares");
        require(balanceOf[msg.sender] >= shares, "Insufficient shares");

        uint256 totalAssetsBefore = totalAssets();
        uint256 amount = (shares * totalAssetsBefore) / totalSupply;

        _burn(msg.sender, shares);

        uint256 vaultBalance = depositToken.balanceOf(address(this));
        if (vaultBalance < amount) {
            uint256 deficit = amount - vaultBalance;
            _withdrawFromStrategies(deficit);
        }

        uint256 fee = (amount * withdrawalFee) / BASIS_POINTS;
        uint256 amountAfterFee = amount - fee;

        if (fee > 0) {
            require(depositToken.transfer(feeRecipient, fee), "Fee transfer failed");
        }
        require(depositToken.transfer(msg.sender, amountAfterFee), "Transfer failed");

        emit Withdraw(msg.sender, amountAfterFee, shares);
    }

    function totalAssets() public view returns (uint256) {
        uint256 total = depositToken.balanceOf(address(this));
        for (uint256 i = 0; i < strategies.length; i++) {
            if (strategies[i].active) {
                total += IStrategy(strategies[i].strategy).balanceOf();
            }
        }
        return total;
    }

    function pricePerShare() external view returns (uint256) {
        if (totalSupply == 0) return 1e18;
        return (totalAssets() * 1e18) / totalSupply;
    }

    // ─── Strategy management ───

    function addStrategy(address _strategy, uint256 _allocPoints) external onlyOwner {
        require(_strategy != address(0), "Zero address");
        require(!strategyExists[_strategy], "Strategy exists");
        require(
            IStrategy(_strategy).want() == address(depositToken),
            "Wrong token"
        );

        strategies.push(StrategyInfo({
            strategy: _strategy,
            allocPoints: _allocPoints,
            totalDeposited: 0,
            active: true
        }));

        strategyExists[_strategy] = true;
        totalAllocPoints += _allocPoints;

        emit StrategyAdded(_strategy, _allocPoints);
    }

    function removeStrategy(uint256 index) external onlyOwner {
        require(index < strategies.length, "Invalid index");
        StrategyInfo storage info = strategies[index];
        require(info.active, "Already inactive");

        if (info.totalDeposited > 0) {
            IStrategy(info.strategy).withdraw(info.totalDeposited);
            info.totalDeposited = 0;
        }

        totalAllocPoints -= info.allocPoints;
        info.active = false;
        info.allocPoints = 0;
        strategyExists[info.strategy] = false;

        emit StrategyRemoved(info.strategy);
    }

    function updateStrategyAllocPoints(uint256 index, uint256 _allocPoints) external onlyOwner {
        require(index < strategies.length, "Invalid index");
        StrategyInfo storage info = strategies[index];
        require(info.active, "Inactive strategy");

        totalAllocPoints = totalAllocPoints - info.allocPoints + _allocPoints;
        info.allocPoints = _allocPoints;

        emit StrategyUpdated(info.strategy, _allocPoints);
    }

    // ─── Harvest & rebalance ───

    function harvest() external nonReentrant {
        uint256 totalProfit = 0;

        for (uint256 i = 0; i < strategies.length; i++) {
            if (strategies[i].active) {
                uint256 profit = IStrategy(strategies[i].strategy).harvest();
                totalProfit += profit;
            }
        }

        uint256 fee = 0;
        if (totalProfit > 0 && performanceFee > 0) {
            fee = (totalProfit * performanceFee) / BASIS_POINTS;
            if (fee > 0) {
                require(depositToken.transfer(feeRecipient, fee), "Fee transfer failed");
            }
        }

        lastHarvestTimestamp = block.timestamp;
        emit Harvest(msg.sender, totalProfit, fee);
    }

    function rebalance() external onlyOwner nonReentrant {
        require(totalAllocPoints > 0, "No alloc points");

        // Withdraw everything from strategies
        for (uint256 i = 0; i < strategies.length; i++) {
            if (strategies[i].active && strategies[i].totalDeposited > 0) {
                IStrategy(strategies[i].strategy).withdraw(strategies[i].totalDeposited);
                strategies[i].totalDeposited = 0;
            }
        }

        uint256 totalAvailable = depositToken.balanceOf(address(this));

        // Redistribute according to allocation points
        for (uint256 i = 0; i < strategies.length; i++) {
            if (strategies[i].active && strategies[i].allocPoints > 0) {
                uint256 allocation = (totalAvailable * strategies[i].allocPoints) / totalAllocPoints;
                if (allocation > 0) {
                    depositToken.approve(strategies[i].strategy, allocation);
                    IStrategy(strategies[i].strategy).deposit(allocation);
                    strategies[i].totalDeposited = allocation;
                }
            }
        }

        emit Rebalance(msg.sender);
    }

    function depositToStrategy(uint256 index, uint256 amount) external onlyOwner nonReentrant {
        require(index < strategies.length, "Invalid index");
        StrategyInfo storage info = strategies[index];
        require(info.active, "Inactive strategy");
        require(amount <= depositToken.balanceOf(address(this)), "Insufficient balance");

        depositToken.approve(info.strategy, amount);
        IStrategy(info.strategy).deposit(amount);
        info.totalDeposited += amount;
    }

    function withdrawFromStrategy(uint256 index, uint256 amount) external onlyOwner nonReentrant {
        require(index < strategies.length, "Invalid index");
        StrategyInfo storage info = strategies[index];
        require(info.active, "Inactive strategy");

        IStrategy(info.strategy).withdraw(amount);
        if (amount >= info.totalDeposited) {
            info.totalDeposited = 0;
        } else {
            info.totalDeposited -= amount;
        }
    }

    // ─── Internal ───

    function _withdrawFromStrategies(uint256 amount) internal {
        uint256 remaining = amount;

        for (uint256 i = 0; i < strategies.length && remaining > 0; i++) {
            if (strategies[i].active && strategies[i].totalDeposited > 0) {
                uint256 toWithdraw = remaining > strategies[i].totalDeposited
                    ? strategies[i].totalDeposited
                    : remaining;

                IStrategy(strategies[i].strategy).withdraw(toWithdraw);
                strategies[i].totalDeposited -= toWithdraw;
                remaining -= toWithdraw;
            }
        }
    }

    // ─── Admin ───

    function setPerformanceFee(uint256 _fee) external onlyOwner {
        require(_fee <= MAX_PERFORMANCE_FEE, "Fee too high");
        performanceFee = _fee;
    }

    function setWithdrawalFee(uint256 _fee) external onlyOwner {
        require(_fee <= MAX_WITHDRAWAL_FEE, "Fee too high");
        withdrawalFee = _fee;
    }

    function setFeeRecipient(address _feeRecipient) external onlyOwner {
        require(_feeRecipient != address(0), "Zero address");
        feeRecipient = _feeRecipient;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Zero address");
        pendingOwner = newOwner;
        emit OwnershipTransferStarted(owner, newOwner);
    }

    function acceptOwnership() external {
        require(msg.sender == pendingOwner, "Not pending owner");
        emit OwnershipTransferred(owner, msg.sender);
        owner = msg.sender;
        pendingOwner = address(0);
    }

    function emergencyWithdraw(address token) external onlyOwner {
        uint256 bal = IERC20(token).balanceOf(address(this));
        if (bal > 0) {
            require(IERC20(token).transfer(owner, bal), "Transfer failed");
        }
    }

    function strategiesLength() external view returns (uint256) {
        return strategies.length;
    }
}