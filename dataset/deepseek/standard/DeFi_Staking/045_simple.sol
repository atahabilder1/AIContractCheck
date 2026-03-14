// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Staking is Ownable {
    IERC20 public token;
    uint256 public rewardRate;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;

    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;

    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;

    constructor(address _token, uint256 _rewardRate) {
        token = IERC20(_token);
        rewardRate = _rewardRate;
    }

    function stake(uint256 amount) public {
        require(amount > 0, "Amount must be greater than zero");
        token.transferFrom(msg.sender, address(this), amount);
        _totalSupply += amount;
        _balances[msg.sender] += amount;
    }

    function withdraw(uint256 amount) public {
        require(amount > 0, "Amount must be greater than zero");
        _totalSupply -= amount;
        _balances[msg.sender] -= amount;
        token.transfer(msg.sender, amount);
    }

    function earned(address account) public view returns (uint256) {
        uint256 currentBalance = _balances[account];
        uint256 currentRewardPerToken = rewardPerToken();
        uint256 hoursSinceLastUpdate = block.timestamp - lastUpdateTime;
        uint256 rewardEarned = (currentBalance * (currentRewardPerToken - userRewardPerTokenPaid[account]) / 1e18) + (hoursSinceLastUpdate * rewardRate);
        return rewardEarned;
    }

    function rewardPerToken() public view returns (uint256) {
        if (_totalSupply == 0) {
            return rewardPerTokenStored;
        }
        return rewardPerTokenStored + ((block.timestamp - lastUpdateTime) * rewardRate * 1e18 / _totalSupply);
    }

    function updateRewards() internal {
        uint256 currentRewardPerToken = rewardPerToken();
        rewardPerTokenStored = currentRewardPerToken;
        lastUpdateTime = block.timestamp;
    }

    function getReward() public {
        uint256 reward = earned(msg.sender);
        if (reward > 0) {
            rewards[msg.sender] = 0;
            token.transfer(msg.sender, reward);
        }
    }

    function setRewardRate(uint256 _rewardRate) public onlyOwner {
        rewardRate = _rewardRate;
    }
}