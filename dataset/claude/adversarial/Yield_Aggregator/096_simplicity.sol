// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IStrategy {
    function deposit(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function balanceOf() external view returns (uint256);
    function harvest() external;
    function want() external view returns (address);
}

contract YieldAggregator is Ownable {
    using SafeERC20 IERC20;

    IERC20 public immutable token;
    IStrategy public strategy;

    mapping(address => uint256) public shares;
    uint256 public totalShares;

    event Deposited(address indexed user, uint256 amount, uint256 shares);
    event Withdrawn(address indexed user, uint256 amount, uint256 shares);
    event StrategyUpdated(address indexed newStrategy);

    constructor(address _token) {
        token = IERC20(_token);
    }

    function setStrategy(address _strategy) external onlyOwner {
        require(IStrategy(_strategy).want() == address(token), "Wrong token");

        if (address(strategy) != address(0)) {
            uint256 bal = strategy.balanceOf();
            if (bal > 0) {
                strategy.withdraw(bal);
            }
        }

        strategy = IStrategy(_strategy);

        uint256 available = token.balanceOf(address(this));
        if (available > 0) {
            token.safeTransfer(address(strategy), available);
            strategy.deposit(available);
        }

        emit StrategyUpdated(_strategy);
    }

    function totalBalance() public view returns (uint256) {
        uint256 inVault = token.balanceOf(address(this));
        uint256 inStrategy = address(strategy) != address(0) ? strategy.balanceOf() : 0;
        return inVault + inStrategy;
    }

    function deposit(uint256 _amount) external {
        require(_amount > 0, "Zero amount");

        uint256 balBefore = totalBalance();
        token.safeTransferFrom(msg.sender, address(this), _amount);

        uint256 newShares;
        if (totalShares == 0) {
            newShares = _amount;
        } else {
            newShares = (_amount * totalShares) / balBefore;
        }

        shares[msg.sender] += newShares;
        totalShares += newShares;

        if (address(strategy) != address(0)) {
            uint256 available = token.balanceOf(address(this));
            token.safeTransfer(address(strategy), available);
            strategy.deposit(available);
        }

        emit Deposited(msg.sender, _amount, newShares);
    }

    function withdraw(uint256 _shares) external {
        require(_shares > 0 && _shares <= shares[msg.sender], "Invalid shares");

        uint256 amount = (_shares * totalBalance()) / totalShares;

        shares[msg.sender] -= _shares;
        totalShares -= _shares;

        uint256 inVault = token.balanceOf(address(this));
        if (inVault < amount) {
            strategy.withdraw(amount - inVault);
        }

        token.safeTransfer(msg.sender, amount);

        emit Withdrawn(msg.sender, amount, _shares);
    }

    function harvest() external {
        require(address(strategy) != address(0), "No strategy");
        strategy.harvest();
    }
}