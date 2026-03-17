// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner_, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender,address recipient,uint256 amount) external returns (bool);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        (bool ok, bytes memory data) = address(token).call(abi.encodeWithSelector(token.transfer.selector, to, value));
        require(ok && (data.length == 0 || abi.decode(data, (bool))), "SafeERC20: transfer failed");
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        (bool ok, bytes memory data) = address(token).call(abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
        require(ok && (data.length == 0 || abi.decode(data, (bool))), "SafeERC20: transferFrom failed");
    }

    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        (bool ok, bytes memory data) = address(token).call(abi.encodeWithSelector(token.approve.selector, spender, value));
        require(ok && (data.length == 0 || abi.decode(data, (bool))), "SafeERC20: approve failed");
    }
}

interface IStrategy {
    function deposit(uint256 amount) external;
    function withdraw(uint256 amount) external returns (uint256);
    function balanceOf() external view returns (uint256);
}

contract YieldAggregator {
    using SafeERC20 for IERC20;

    // ERC20 share token storage
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    // Core aggregator state
    IERC20 public immutable asset;
    address public owner;
    IStrategy public strategy;

    // Reentrancy guard
    uint256 private locked;

    // Events
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner_, address indexed spender, uint256 value);

    event Deposit(address indexed user, uint256 assets, uint256 shares);
    event Withdraw(address indexed user, uint256 shares, uint256 assets);
    event Earn(uint256 amount);
    event StrategyUpdated(address indexed oldStrategy, address indexed newStrategy);
    event OwnerUpdated(address indexed oldOwner, address indexed newOwner);

    modifier nonReentrant() {
        require(locked == 0, "REENTRANCY");
        locked = 1;
        _;
        locked = 0;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "NOT_OWNER");
        _;
    }

    constructor(IERC20 _asset, string memory _name, string memory _symbol) {
        asset = _asset;
        name = _name;
        symbol = _symbol;
        owner = msg.sender;
        emit OwnerUpdated(address(0), msg.sender);
    }

    // -------- ERC20 share token --------

    function _mint(address to, uint256 value) internal {
        totalSupply += value;
        balanceOf[to] += value;
        emit Transfer(address(0), to, value);
    }

    function _burn(address from, uint256 value) internal {
        balanceOf[from] -= value;
        totalSupply -= value;
        emit Transfer(from, address(0), value);
    }

    function transfer(address to, uint256 value) external returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function approve(address spender, uint256 value) external returns (bool) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            require(allowed >= value, "ALLOWANCE");
            allowance[from][msg.sender] = allowed - value;
            emit Approval(from, msg.sender, allowance[from][msg.sender]);
        }
        _transfer(from, to, value);
        return true;
    }

    function _transfer(address from, address to, uint256 value) internal {
        require(to != address(0), "BAD_TO");
        balanceOf[from] -= value;
        balanceOf[to] += value;
        emit Transfer(from, to, value);
    }

    // -------- Core aggregator logic --------

    function totalAssets() public view returns (uint256) {
        uint256 stratBal = address(strategy) == address(0) ? 0 : strategy.balanceOf();
        return asset.balanceOf(address(this)) + stratBal;
    }

    function deposit(uint256 assets_) external nonReentrant returns (uint256 shares_) {
        require(assets_ > 0, "ZERO_ASSETS");
        uint256 assetsBefore = totalAssets();

        asset.safeTransferFrom(msg.sender, address(this), assets_);

        if (totalSupply == 0 || assetsBefore == 0) {
            shares_ = assets_;
        } else {
            shares_ = assets_ * totalSupply / assetsBefore;
        }
        require(shares_ > 0, "ZERO_SHARES");

        _mint(msg.sender, shares_);
        emit Deposit(msg.sender, assets_, shares_);

        // Auto-invest newly available funds if strategy set
        if (address(strategy) != address(0)) {
            _earn();
        }
    }

    function withdraw(uint256 shares_) external nonReentrant returns (uint256 assetsOut) {
        require(shares_ > 0, "ZERO_SHARES");
        require(balanceOf[msg.sender] >= shares_, "INSUFFICIENT_SHARES");

        uint256 assetsBefore = totalAssets();
        assetsOut = shares_ * assetsBefore / totalSupply;

        _burn(msg.sender, shares_);

        uint256 bal = asset.balanceOf(address(this));
        if (bal < assetsOut && address(strategy) != address(0)) {
            uint256 needed = assetsOut - bal;
            strategy.withdraw(needed);
            bal = asset.balanceOf(address(this));
        }

        uint256 toSend = bal < assetsOut ? bal : assetsOut;
        require(toSend > 0, "NO_FUNDS");
        asset.safeTransfer(msg.sender, toSend);

        emit Withdraw(msg.sender, shares_, toSend);
    }

    function earn() external nonReentrant {
        require(address(strategy) != address(0), "NO_STRATEGY");
        _earn();
    }

    function _earn() internal {
        uint256 amt = asset.balanceOf(address(this));
        if (amt > 0) {
            asset.safeApprove(address(strategy), 0);
            asset.safeApprove(address(strategy), amt);
            strategy.deposit(amt);
            emit Earn(amt);
        }
    }

    // -------- Admin --------

    function setStrategy(IStrategy newStrategy) external onlyOwner nonReentrant {
        address old = address(strategy);
        if (old != address(0)) {
            // Withdraw all from old strategy
            uint256 bal = IStrategy(old).balanceOf();
            if (bal > 0) {
                IStrategy(old).withdraw(bal);
            }
        }
        strategy = newStrategy;
        // Push any idle funds into new strategy
        if (address(newStrategy) != address(0)) {
            _earn();
        }
        emit StrategyUpdated(old, address(newStrategy));
    }

    function setOwner(address newOwner) external onlyOwner {
        require(newOwner != address(0), "ZERO_OWNER");
        emit OwnerUpdated(owner, newOwner);
        owner = newOwner;
    }
}