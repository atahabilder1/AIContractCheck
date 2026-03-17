// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external pure returns (uint8);
    function totalSupply() external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function transfer(address,uint256) external returns (bool);
    function allowance(address,address) external view returns (uint256);
    function approve(address,uint256) external returns (bool);
    function transferFrom(address,address,uint256) external returns (bool);

    event Transfer(address indexed from,address indexed to,uint256 value);
    event Approval(address indexed owner,address indexed spender,uint256 value);
}

contract MinimalERC20 is IERC20 {
    string private _name;
    string private _symbol;
    uint8 public constant override decimals = 18;

    uint256 public override totalSupply;
    mapping(address => uint256) public override balanceOf;
    mapping(address => mapping(address => uint256)) public override allowance;

    address public immutable minter;

    modifier onlyMinter() {
        require(msg.sender == minter, "Not minter");
        _;
    }

    constructor(string memory name_, string memory symbol_, address minter_) {
        _name = name_;
        _symbol = symbol_;
        minter = minter_;
    }

    function name() external view override returns (string memory) { return _name; }
    function symbol() external view override returns (string memory) { return _symbol; }

    function transfer(address to, uint256 amount) external override returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external override returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external override returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        require(allowed >= amount, "Insufficient allowance");
        if (allowed != type(uint256).max) {
            allowance[from][msg.sender] = allowed - amount;
            emit Approval(from, msg.sender, allowance[from][msg.sender]);
        }
        _transfer(from, to, amount);
        return true;
    }

    function mint(address to, uint256 amount) external onlyMinter {
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(to != address(0), "Zero address");
        uint256 bal = balanceOf[from];
        require(bal >= amount, "Insufficient balance");
        unchecked {
            balanceOf[from] = bal - amount;
            balanceOf[to] += amount;
        }
        emit Transfer(from, to, amount);
    }
}

abstract contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status = _NOT_ENTERED;

    modifier nonReentrant() {
        require(_status != _ENTERED, "Reentrancy");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
}

contract MinimalCrowdsale is ReentrancyGuard {
    event Contributed(address indexed contributor, uint256 amount, uint256 tokensMinted);
    event RefundClaimed(address indexed contributor, uint256 amount);
    event FundsWithdrawn(address indexed to, uint256 amount);

    address public immutable owner;
    MinimalERC20 public immutable token;

    uint256 public immutable startTime;
    uint256 public immutable endTime;
    uint256 public immutable goal;      // soft cap in wei
    uint256 public immutable rate;      // tokens per wei

    uint256 public totalRaised;
    mapping(address => uint256) public contributions;

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor(
        string memory tokenName,
        string memory tokenSymbol,
        uint256 rate_,         // tokens per wei, e.g., 1000e18 / 1e18 => 1000 tokens per ETH
        uint256 goal_,         // wei
        uint256 startTime_,    // unix timestamp
        uint256 endTime_       // unix timestamp
    ) {
        require(rate_ > 0, "Rate=0");
        require(goal_ > 0, "Goal=0");
        require(startTime_ < endTime_, "Bad time");

        owner = msg.sender;
        rate = rate_;
        goal = goal_;
        startTime = startTime_;
        endTime = endTime_;

        token = new MinimalERC20(tokenName, tokenSymbol, address(this));
    }

    receive() external payable {
        _contribute(msg.sender, msg.value);
    }

    function contribute() external payable nonReentrant {
        _contribute(msg.sender, msg.value);
    }

    function withdrawFunds() external onlyOwner nonReentrant {
        require(block.timestamp > endTime, "Sale not ended");
        require(totalRaised >= goal, "Goal not reached");
        uint256 amount = address(this).balance;
        require(amount > 0, "No funds");
        (bool ok, ) = payable(owner).call{value: amount}("");
        require(ok, "Withdraw failed");
        emit FundsWithdrawn(owner, amount);
    }

    function claimRefund() external nonReentrant {
        require(block.timestamp > endTime, "Sale not ended");
        require(totalRaised < goal, "Goal reached");
        uint256 contributed = contributions[msg.sender];
        require(contributed > 0, "Nothing to refund");
        contributions[msg.sender] = 0;
        (bool ok, ) = payable(msg.sender).call{value: contributed}("");
        require(ok, "Refund failed");
        emit RefundClaimed(msg.sender, contributed);
    }

    function saleActive() public view returns (bool) {
        return block.timestamp >= startTime && block.timestamp <= endTime;
    }

    function _contribute(address sender, uint256 value) internal {
        require(saleActive(), "Not active");
        require(value > 0, "Zero amount");
        contributions[sender] += value;
        totalRaised += value;

        uint256 tokensToMint = value * rate;
        token.mint(sender, tokensToMint);

        emit Contributed(sender, value, tokensToMint);
    }
}