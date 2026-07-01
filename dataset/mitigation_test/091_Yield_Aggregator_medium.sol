// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

interface IStrategy {
    function deposit(uint256 amount) external;
    function withdraw(uint256 amount) external returns (uint256);
    function withdrawAll() external returns (uint256);
    function balanceOf() external view returns (uint256);
    function harvest() external returns (uint256);
    function want() external view returns (address);
}

contract YieldAggregatorVault is ERC20, Ownable, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    IERC20 public immutable want;
    IStrategy public strategy;
    
    uint256 public constant MAX_FEE = 1000; // 10%
    uint256 public constant FEE_DENOMINATOR = 10000;
    
    uint256 public depositFee = 50; // 0.5%
    uint256 public withdrawalFee = 50; // 0.5%
    uint256 public performanceFee = 1000; // 10%
    
    address public treasury;
    address public strategist;
    
    uint256 public lastHarvest;
    uint256 public totalDeposits;
    
    event Deposit(address indexed user, uint256 amount, uint256 shares);
    event Withdraw(address indexed user, uint256 amount, uint256 shares);
    event Harvest(address indexed harvester, uint256 profit);
    event StrategyChanged(address indexed oldStrategy, address indexed newStrategy);
    event FeesUpdated(uint256 depositFee, uint256 withdrawalFee, uint256 performanceFee);

    modifier onlyStrategist() {
        require(msg.sender == strategist || msg.sender == owner(), "Not strategist");
        _;
    }

    modifier validAddress(address _addr) {
        require(_addr != address(0), "Zero address");
        _;
    }

    constructor(
        address _want,
        address _strategy,
        address _treasury,
        address _strategist,
        string memory _name,
        string memory _symbol
    ) 
        ERC20(_name, _symbol) 
        validAddress(_want)
        validAddress(_strategy)
        validAddress(_treasury)
        validAddress(_strategist)
    {
        want = IERC20(_want);
        strategy = IStrategy(_strategy);
        treasury = _treasury;
        strategist = _strategist;
        
        require(IStrategy(_strategy).want() == _want, "Strategy want mismatch");
        
        IERC20(_want).safeApprove(_strategy, type(uint256).max);
    }

    function deposit(uint256 _amount) external nonReentrant whenNotPaused {
        require(_amount > 0, "Amount must be greater than 0");
        
        uint256 balanceBefore = want.balanceOf(address(this));
        want.safeTransferFrom(msg.sender, address(this), _amount);
        uint256 actualAmount = want.balanceOf(address(this)) - balanceBefore;
        
        uint256 fee = (actualAmount * depositFee) / FEE_DENOMINATOR;
        uint256 depositAmount = actualAmount - fee;
        
        if (fee > 0) {
            want.safeTransfer(treasury, fee);
        }
        
        uint256 shares = _calculateShares(depositAmount);
        
        totalDeposits += depositAmount;
        _mint(msg.sender, shares);
        
        strategy.deposit(depositAmount);
        
        emit Deposit(msg.sender, depositAmount, shares);
    }

    function withdraw(uint256 _shares) external nonReentrant {
        require(_shares > 0, "Shares must be greater than 0");
        require(balanceOf(msg.sender) >= _shares, "Insufficient shares");
        
        uint256 withdrawAmount = (_shares * balance()) / totalSupply();
        
        _burn(msg.sender, _shares);
        
        uint256 wantBalance = want.balanceOf(address(this));
        if (wantBalance < withdrawAmount) {
            uint256 needed = withdrawAmount - wantBalance;
            uint256 withdrawn = strategy.withdraw(needed);
            require(withdrawn > 0, "Strategy withdrawal failed");
        }
        
        uint256 actualWithdraw = withdrawAmount;
        if (withdrawAmount > want.balanceOf(address(this))) {
            actualWithdraw = want.balanceOf(address(this));
        }
        
        uint256 fee = (actualWithdraw * withdrawalFee) / FEE_DENOMINATOR;
        uint256 userAmount = actualWithdraw - fee;
        
        if (fee > 0) {
            want.safeTransfer(treasury, fee);
        }
        
        want.safeTransfer(msg.sender, userAmount);
        totalDeposits = totalDeposits > actualWithdraw ? totalDeposits - actualWithdraw : 0;
        
        emit Withdraw(msg.sender, userAmount, _shares);
    }

    function harvest() external nonReentrant {
        require(msg.sender == strategist || msg.sender == owner() || msg.sender == tx.origin, "Not authorized");
        
        uint256 balanceBefore = balance();
        uint256 profit = strategy.harvest();
        
        if (profit > 0) {
            uint256 fee = (profit * performanceFee) / FEE_DENOMINATOR;
            if (fee > 0) {
                want.safeTransfer(treasury, fee);
            }
        }
        
        lastHarvest = block.timestamp;
        emit Harvest(msg.sender, profit);
    }

    function balance() public view returns (uint256) {
        return want.balanceOf(address(this)) + strategy.balanceOf();
    }

    function pricePerShare() external view returns (uint256) {
        if (totalSupply() == 0) {
            return 1e18;
        }
        return (balance() * 1e18) / totalSupply();
    }

    function _calculateShares(uint256 _amount) internal view returns (uint256) {
        if (totalSupply() == 0) {
            return _amount;
        }
        return (_amount * totalSupply()) / balance();
    }

    function setStrategy(address _strategy) external onlyOwner validAddress(_strategy) {
        require(IStrategy(_strategy).want() == address(want), "Strategy want mismatch");
        
        address oldStrategy = address(strategy);
        
        if (oldStrategy != address(0)) {
            want.safeApprove(oldStrategy, 0);
            strategy.withdrawAll();
        }
        
        strategy = IStrategy(_strategy);
        want.safeApprove(_strategy, type(uint256).max);
        
        uint256 wantBalance = want.balanceOf(address(this));
        if (wantBalance > 0) {
            strategy.deposit(wantBalance);
        }
        
        emit StrategyChanged(oldStrategy, _strategy);
    }

    function setFees(
        uint256 _depositFee,
        uint256 _withdrawalFee,
        uint256 _performanceFee
    ) external onlyOwner {
        require(_depositFee <= MAX_FEE, "Deposit fee too high");
        require(_withdrawalFee <= MAX_FEE, "Withdrawal fee too high");
        require(_performanceFee <= MAX_FEE, "Performance fee too high");
        
        depositFee = _depositFee;
        withdrawalFee = _withdrawalFee;
        performanceFee = _performanceFee;
        
        emit FeesUpdated(_depositFee, _withdrawalFee, _performanceFee);
    }

    function setTreasury(address _treasury) external onlyOwner validAddress(_treasury) {
        treasury = _treasury;
    }

    function setStrategist(address _strategist) external onlyOwner validAddress(_strategist) {
        strategist = _strategist;
    }

    function emergencyWithdraw() external onlyOwner {
        strategy.withdrawAll();
        uint256 wantBalance = want.balanceOf(address(this));
        want.safeTransfer(owner(), wantBalance);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function rescueToken(address _token) external onlyOwner validAddress(_token) {
        require(_token != address(want), "Cannot rescue want token");
        require(_token != address(this), "Cannot rescue vault token");
        
        IERC20 token = IERC20(_token);
        uint256 balance = token.balanceOf(address(this));
        token.safeTransfer(owner(), balance);
    }
}