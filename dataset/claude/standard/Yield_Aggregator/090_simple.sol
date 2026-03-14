// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IStrategy {
    function deposit(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function balanceOf() external view returns (uint256);
}

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract YieldVault {
    IERC20 public immutable token;
    IStrategy public strategy;
    address public owner;

    string public name;
    string public symbol;
    uint8 public constant decimals = 18;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;

    event Deposit(address indexed user, uint256 amount, uint256 shares);
    event Withdraw(address indexed user, uint256 amount, uint256 shares);

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    constructor(address _token, address _strategy, string memory _name, string memory _symbol) {
        token = IERC20(_token);
        strategy = IStrategy(_strategy);
        owner = msg.sender;
        name = _name;
        symbol = _symbol;
    }

    function totalAssets() public view returns (uint256) {
        return strategy.balanceOf();
    }

    function deposit(uint256 amount) external returns (uint256 shares) {
        require(amount > 0, "zero amount");

        uint256 totalBefore = totalAssets();

        token.transferFrom(msg.sender, address(this), amount);
        token.approve(address(strategy), amount);
        strategy.deposit(amount);

        if (totalSupply == 0) {
            shares = amount;
        } else {
            shares = (amount * totalSupply) / totalBefore;
        }

        totalSupply += shares;
        balanceOf[msg.sender] += shares;

        emit Deposit(msg.sender, amount, shares);
    }

    function withdraw(uint256 shares) external returns (uint256 amount) {
        require(shares > 0, "zero shares");
        require(balanceOf[msg.sender] >= shares, "insufficient shares");

        amount = (shares * totalAssets()) / totalSupply;

        balanceOf[msg.sender] -= shares;
        totalSupply -= shares;

        strategy.withdraw(amount);
        token.transfer(msg.sender, amount);

        emit Withdraw(msg.sender, amount, shares);
    }

    function pricePerShare() external view returns (uint256) {
        if (totalSupply == 0) return 1e18;
        return (totalAssets() * 1e18) / totalSupply;
    }

    function setStrategy(address _strategy) external onlyOwner {
        uint256 bal = totalAssets();
        if (bal > 0) {
            strategy.withdraw(bal);
        }

        strategy = IStrategy(_strategy);

        uint256 tokenBal = token.balanceOf(address(this));
        if (tokenBal > 0) {
            token.approve(_strategy, tokenBal);
            strategy.deposit(tokenBal);
        }
    }
}