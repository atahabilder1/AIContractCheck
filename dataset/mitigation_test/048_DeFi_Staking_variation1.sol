// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract LiquidStakingContract is ERC20, ReentrancyGuard, Ownable, Pausable {
    using SafeERC20 for IERC20;

    IERC20 public immutable stakingToken;
    
    uint256 public totalStaked;
    uint256 public totalRewards;
    uint256 public constant MINIMUM_STAKE = 1e15; // 0.001 tokens
    uint256 public constant MAX_STAKE_PER_TX = 1000000e18; // 1M tokens
    uint256 public exchangeRate = 1e18; // 1:1 initial rate
    
    mapping(address => uint256) public lastStakeTime;
    uint256 public constant UNSTAKE_DELAY = 7 days;
    
    event Staked(address indexed user, uint256 amount, uint256 stTokensMinted);
    event Unstaked(address indexed user, uint256 stTokensBurned, uint256 tokensReturned);
    event RewardsDistributed(uint256 amount);
    event ExchangeRateUpdated(uint256 newRate);

    modifier validAddress(address _addr) {
        require(_addr != address(0), "Invalid address");
        _;
    }

    modifier validAmount(uint256 _amount) {
        require(_amount > 0, "Amount must be greater than 0");
        require(_amount >= MINIMUM_STAKE, "Amount below minimum stake");
        require(_amount <= MAX_STAKE_PER_TX, "Amount exceeds maximum per transaction");
        _;
    }

    constructor(
        address _stakingToken,
        string memory _name,
        string memory _symbol
    ) ERC20(_name, _symbol) validAddress(_stakingToken) {
        stakingToken = IERC20(_stakingToken);
    }

    function stake(uint256 _amount) 
        external 
        nonReentrant 
        whenNotPaused 
        validAmount(_amount) 
    {
        address user = msg.sender;
        
        // Checks
        require(stakingToken.balanceOf(user) >= _amount, "Insufficient balance");
        require(stakingToken.allowance(user, address(this)) >= _amount, "Insufficient allowance");
        
        // Effects
        uint256 stTokensToMint = (_amount * 1e18) / exchangeRate;
        require(stTokensToMint > 0, "Mint amount too small");
        
        totalStaked += _amount;
        lastStakeTime[user] = block.timestamp;
        
        _mint(user, stTokensToMint);
        
        // Interactions
        stakingToken.safeTransferFrom(user, address(this), _amount);
        
        emit Staked(user, _amount, stTokensToMint);
    }

    function unstake(uint256 _stTokenAmount) 
        external 
        nonReentrant 
        whenNotPaused 
    {
        address user = msg.sender;
        
        // Checks
        require(_stTokenAmount > 0, "Amount must be greater than 0");
        require(balanceOf(user) >= _stTokenAmount, "Insufficient stToken balance");
        require(
            block.timestamp >= lastStakeTime[user] + UNSTAKE_DELAY, 
            "Unstake delay not met"
        );
        
        uint256 tokensToReturn = (_stTokenAmount * exchangeRate) / 1e18;
        require(tokensToReturn > 0, "Return amount too small");
        require(stakingToken.balanceOf(address(this)) >= tokensToReturn, "Insufficient contract balance");
        
        // Effects
        totalStaked -= tokensToReturn;
        _burn(user, _stTokenAmount);
        
        // Interactions
        stakingToken.safeTransfer(user, tokensToReturn);
        
        emit Unstaked(user, _stTokenAmount, tokensToReturn);
    }

    function distributeRewards(uint256 _rewardAmount) 
        external 
        onlyOwner 
        nonReentrant 
        validAmount(_rewardAmount) 
    {
        // Checks
        require(totalSupply() > 0, "No stakers to distribute rewards to");
        require(
            stakingToken.balanceOf(msg.sender) >= _rewardAmount, 
            "Insufficient reward balance"
        );
        require(
            stakingToken.allowance(msg.sender, address(this)) >= _rewardAmount, 
            "Insufficient reward allowance"
        );
        
        // Effects
        totalRewards += _rewardAmount;
        uint256 newExchangeRate = ((totalStaked + totalRewards) * 1e18) / totalSupply();
        exchangeRate = newExchangeRate;
        
        // Interactions
        stakingToken.safeTransferFrom(msg.sender, address(this), _rewardAmount);
        
        emit RewardsDistributed(_rewardAmount);
        emit ExchangeRateUpdated(newExchangeRate);
    }

    function getStakedAmount(address _user) external view returns (uint256) {
        if (balanceOf(_user) == 0) return 0;
        return (balanceOf(_user) * exchangeRate) / 1e18;
    }

    function getUnstakeTime(address _user) external view returns (uint256) {
        return lastStakeTime[_user] + UNSTAKE_DELAY;
    }

    function canUnstake(address _user) external view returns (bool) {
        return block.timestamp >= lastStakeTime[_user] + UNSTAKE_DELAY;
    }

    function emergencyWithdraw() external onlyOwner {
        uint256 balance = stakingToken.balanceOf(address(this));
        require(balance > 0, "No tokens to withdraw");
        
        stakingToken.safeTransfer(owner(), balance);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override whenNotPaused {
        super._beforeTokenTransfer(from, to, amount);
        
        if (to != address(0) && from != address(0)) {
            // Update last stake time for recipient to prevent immediate unstaking
            lastStakeTime[to] = block.timestamp;
        }
    }
}