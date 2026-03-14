// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IStrategy {
    function deposit() external;
    function withdraw(uint256 _amount) external;
    function harvest() external;
    function balanceOf() external view returns (uint256);
}

contract YieldAggregatorVault {
    IERC20 public immutable token;
    IStrategy public strategy;
    address public owner;
    uint256 public depositFee; // in basis points (100 = 1%)
    uint256 public withdrawalFee; // in basis points (100 = 1%)

    mapping(address => uint256) private balances;
    uint256 private totalSupply;

    event Deposit(address indexed user, uint256 amount, uint256 fee);
    event Withdraw(address indexed user, uint256 amount, uint256 fee);
    event StrategyUpdated(address newStrategy);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    constructor(
        IERC20 _token,
        IStrategy _strategy,
        uint256 _depositFee,
        uint256 _withdrawalFee
    ) {
        token = _token;
        strategy = _strategy;
        owner = msg.sender;
        depositFee = _depositFee;
        withdrawalFee = _withdrawalFee;
    }

    function deposit(uint256 _amount) external {
        require(_amount > 0, "Invalid amount");

        uint256 fee = (_amount * depositFee) / 10000;
        uint256 amountToDeposit = _amount - fee;

        token.transferFrom(msg.sender, address(this), _amount);
        token.approve(address(strategy), amountToDeposit);
        strategy.deposit();

        balances[msg.sender] += amountToDeposit;
        totalSupply += amountToDeposit;

        emit Deposit(msg.sender, amountToDeposit, fee);
    }

    function withdraw(uint256 _amount) external {
        require(_amount > 0 && _amount <= balances[msg.sender], "Invalid amount");

        uint256 fee = (_amount * withdrawalFee) / 10000;
        uint256 amountToWithdraw = _amount - fee;

        strategy.withdraw(amountToWithdraw);
        token.transfer(msg.sender, amountToWithdraw);

        balances[msg.sender] -= _amount;
        totalSupply -= _amount;

        emit Withdraw(msg.sender, amountToWithdraw, fee);
    }

    function balanceOf(address _user) external view returns (uint256) {
        return balances[_user];
    }

    function totalBalance() external view returns (uint256) {
        return strategy.balanceOf();
    }

    function updateStrategy(IStrategy _newStrategy) external onlyOwner {
        strategy = _newStrategy;
        emit StrategyUpdated(address(_newStrategy));
    }

    function harvest() external onlyOwner {
        strategy.harvest();
    }
}

interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
}