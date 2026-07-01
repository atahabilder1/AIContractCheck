// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract WrappedTokenWithFees is ERC20, ReentrancyGuard, Ownable, Pausable {
    using SafeERC20 for IERC20;

    IERC20 public immutable underlyingToken;
    
    uint256 public constant MAX_UNWRAP_FEE = 1000; // 10% max
    uint256 public constant MIN_HOLDING_PERIOD = 30 days;
    uint256 public constant PRECISION = 10000;
    
    uint256 public unwrapFee = 100; // 1% default
    uint256 public totalFeesCollected;
    uint256 public totalDistributed;
    uint256 public lastDistributionTime;
    
    struct HolderInfo {
        uint256 balance;
        uint256 lastUpdateTime;
        uint256 accumulatedRewards;
        uint256 rewardDebt;
    }
    
    mapping(address => HolderInfo) public holders;
    mapping(address => bool) public isEligibleHolder;
    
    uint256 public accRewardPerShare;
    uint256 public totalEligibleSupply;
    
    event Wrapped(address indexed user, uint256 amount);
    event Unwrapped(address indexed user, uint256 amount, uint256 fee);
    event FeesDistributed(uint256 amount, uint256 timestamp);
    event UnwrapFeeUpdated(uint256 oldFee, uint256 newFee);
    event RewardsClaimed(address indexed user, uint256 amount);

    modifier validAddress(address _address) {
        require(_address != address(0), "Invalid address");
        _;
    }

    modifier validAmount(uint256 _amount) {
        require(_amount > 0, "Amount must be greater than zero");
        _;
    }

    constructor(
        address _underlyingToken,
        string memory _name,
        string memory _symbol
    ) ERC20(_name, _symbol) validAddress(_underlyingToken) {
        underlyingToken = IERC20(_underlyingToken);
        lastDistributionTime = block.timestamp;
    }

    function wrap(uint256 _amount) 
        external 
        nonReentrant 
        whenNotPaused 
        validAmount(_amount) 
    {
        _updateRewards(msg.sender);
        
        underlyingToken.safeTransferFrom(msg.sender, address(this), _amount);
        _mint(msg.sender, _amount);
        
        _updateHolderInfo(msg.sender);
        
        emit Wrapped(msg.sender, _amount);
    }

    function unwrap(uint256 _amount) 
        external 
        nonReentrant 
        whenNotPaused 
        validAmount(_amount) 
    {
        require(balanceOf(msg.sender) >= _amount, "Insufficient balance");
        
        _updateRewards(msg.sender);
        
        uint256 fee = (_amount * unwrapFee) / PRECISION;
        uint256 amountAfterFee = _amount - fee;
        
        require(amountAfterFee > 0, "Amount too small");
        require(
            underlyingToken.balanceOf(address(this)) >= amountAfterFee,
            "Insufficient underlying tokens"
        );
        
        _burn(msg.sender, _amount);
        totalFeesCollected += fee;
        
        underlyingToken.safeTransfer(msg.sender, amountAfterFee);
        
        _updateHolderInfo(msg.sender);
        
        emit Unwrapped(msg.sender, amountAfterFee, fee);
    }

    function distributeFees() external nonReentrant whenNotPaused {
        require(totalEligibleSupply > 0, "No eligible holders");
        require(totalFeesCollected > totalDistributed, "No fees to distribute");
        
        uint256 feesToDistribute = totalFeesCollected - totalDistributed;
        require(feesToDistribute > 0, "No fees available");
        
        accRewardPerShare += (feesToDistribute * 1e18) / totalEligibleSupply;
        totalDistributed = totalFeesCollected;
        lastDistributionTime = block.timestamp;
        
        emit FeesDistributed(feesToDistribute, block.timestamp);
    }

    function claimRewards() external nonReentrant whenNotPaused {
        _updateRewards(msg.sender);
        
        uint256 rewards = holders[msg.sender].accumulatedRewards;
        require(rewards > 0, "No rewards to claim");
        
        holders[msg.sender].accumulatedRewards = 0;
        
        require(
            underlyingToken.balanceOf(address(this)) >= rewards,
            "Insufficient contract balance"
        );
        
        underlyingToken.safeTransfer(msg.sender, rewards);
        
        emit RewardsClaimed(msg.sender, rewards);
    }

    function _updateRewards(address _holder) internal {
        HolderInfo storage holder = holders[_holder];
        
        if (isEligibleHolder[_holder] && holder.balance > 0) {
            uint256 pending = (holder.balance * accRewardPerShare) / 1e18 - holder.rewardDebt;
            holder.accumulatedRewards += pending;
        }
        
        holder.rewardDebt = (holder.balance * accRewardPerShare) / 1e18;
    }

    function _updateHolderInfo(address _holder) internal {
        HolderInfo storage holder = holders[_holder];
        uint256 newBalance = balanceOf(_holder);
        
        bool wasEligible = isEligibleHolder[_holder];
        bool isNowEligible = _isEligibleForRewards(_holder);
        
        if (wasEligible && !isNowEligible) {
            totalEligibleSupply -= holder.balance;
            isEligibleHolder[_holder] = false;
        } else if (!wasEligible && isNowEligible) {
            totalEligibleSupply += newBalance;
            isEligibleHolder[_holder] = true;
        } else if (wasEligible && isNowEligible) {
            totalEligibleSupply = totalEligibleSupply - holder.balance + newBalance;
        }
        
        holder.balance = newBalance;
        holder.lastUpdateTime = block.timestamp;
        holder.rewardDebt = (newBalance * accRewardPerShare) / 1e18;
    }

    function _isEligibleForRewards(address _holder) internal view returns (bool) {
        if (balanceOf(_holder) == 0) return false;
        
        HolderInfo memory holder = holders[_holder];
        if (holder.lastUpdateTime == 0) return false;
        
        return block.timestamp >= holder.lastUpdateTime + MIN_HOLDING_PERIOD;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        super._beforeTokenTransfer(from, to, amount);
        
        if (from != address(0)) {
            _updateRewards(from);
        }
        if (to != address(0)) {
            _updateRewards(to);
        }
    }

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        super._afterTokenTransfer(from, to, amount);
        
        if (from != address(0) && from != to) {
            _updateHolderInfo(from);
        }
        if (to != address(0) && from != to) {
            _updateHolderInfo(to);
        }
    }

    function setUnwrapFee(uint256 _newFee) external onlyOwner {
        require(_newFee <= MAX_UNWRAP_FEE, "Fee too high");
        
        uint256 oldFee = unwrapFee;
        unwrapFee = _newFee;
        
        emit UnwrapFeeUpdated(oldFee, _newFee);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function emergencyWithdraw(address _token, uint256 _amount) 
        external 
        onlyOwner 
        validAddress(_token)
        validAmount(_amount)
    {
        require(_token != address(underlyingToken), "Cannot withdraw underlying token");
        IERC20(_token).safeTransfer(owner(), _amount);
    }

    function getPendingRewards(address _holder) external view returns (uint256) {
        if (!isEligibleHolder[_holder] || holders[_holder].balance == 0) {
            return holders[_holder].accumulatedRewards;
        }
        
        uint256 pending = (holders[_holder].balance * accRewardPerShare) / 1e18 - holders[_holder].rewardDebt;
        return holders[_holder].accumulatedRewards + pending;
    }

    function getHolderInfo(address _holder) external view returns (
        uint256 balance,
        uint256 lastUpdateTime,
        uint256 accumulatedRewards,
        bool eligible,
        uint256 timeUntilEligible
    ) {
        HolderInfo memory holder = holders[_holder];
        balance = holder.balance;
        lastUpdateTime = holder.lastUpdateTime;
        accumulatedRewards = holder.accumulatedRewards;
        eligible = isEligibleHolder[_holder];
        
        if (!eligible && holder.lastUpdateTime > 0) {
            uint256 timeElapsed = block.timestamp - holder.lastUpdateTime;
            timeUntilEligible = timeElapsed >= MIN_HOLDING_PERIOD ? 0 : MIN_HOLDING_PERIOD - timeElapsed;
        }
    }

    function getContractStats() external view returns (
        uint256 totalSupply_,
        uint256 totalFeesCollected_,
        uint256 totalDistributed_,
        uint256 totalEligibleSupply_,
        uint256 unwrapFee_,
        uint256 lastDistributionTime_
    ) {
        return (
            totalSupply(),
            totalFeesCollected,
            totalDistributed,
            totalEligibleSupply,
            unwrapFee,
            lastDistributionTime
        );
    }
}