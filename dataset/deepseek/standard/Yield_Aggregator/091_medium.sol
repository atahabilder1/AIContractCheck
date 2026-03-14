// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IStrategy {
    function deposit(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function withdrawAll() external;
    function getReward() external;
}

contract YieldAggregatorVault {
    using SafeMath for uint256;

    IStrategy public strategy;
    uint256 public totalDeposits;
    uint256 public depositFeePercentage;
    uint256 public withdrawalFeePercentage;

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event Harvest(uint256 amount);

    constructor(address _strategy, uint256 _depositFeePercentage, uint256 _withdrawalFeePercentage) {
        require(_strategy != address(0), "Invalid strategy address");
        strategy = IStrategy(_strategy);
        depositFeePercentage = _depositFeePercentage;
        withdrawalFeePercentage = _withdrawalFeePercentage;
    }

    function deposit(uint256 amount) external {
        require(amount > 0, "Amount must be greater than zero");
        uint256 fee = amount.mul(depositFeePercentage).div(100);
        uint256 netAmount = amount.sub(fee);
        require(IERC20(address(strategy)).transferFrom(msg.sender, address(this), amount), "Transfer failed");
        require(IERC20(address(strategy)).approve(address(strategy), netAmount), "Approval failed");
        strategy.deposit(netAmount);
        totalDeposits = totalDeposits.add(netAmount);
        emit Deposit(msg.sender, netAmount);
    }

    function withdraw(uint256 amount) external {
        require(amount > 0, "Amount must be greater than zero");
        uint256 fee = amount.mul(withdrawalFeePercentage).div(100);
        uint256 netAmount = amount.sub(fee);
        strategy.withdraw(netAmount);
        require(IERC20(address(strategy)).transfer(msg.sender, netAmount), "Transfer failed");
        totalDeposits = totalDeposits.sub(amount);
        emit Withdraw(msg.sender, netAmount);
    }

    function harvest() external {
        strategy.getReward();
        emit Harvest(IERC20(address(strategy)).balanceOf(address(this)));
    }

    function setStrategy(address _strategy) external {
        require(_strategy != address(0), "Invalid strategy address");
        strategy = IStrategy(_strategy);
    }

    function setDepositFeePercentage(uint256 _depositFeePercentage) external {
        depositFeePercentage = _depositFeePercentage;
    }

    function setWithdrawalFeePercentage(uint256 _withdrawalFeePercentage) external {
        withdrawalFeePercentage = _withdrawalFeePercentage;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath: subtraction overflow");
        return a - b;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) return 0;
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: division by zero");
        return a / b;
    }
}