// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-solidity/contracts/token/ERC721/ERC721.sol";
import "https://github.com/OpenZeppelin/openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";

contract StakingNFT is ERC721, ERC20 {
    address public stakingContract;
    uint256 public rewardRate;
    uint256 public rewardDuration;
    uint256 public totalStaked;

    constructor(string memory _name, string memory _symbol, address _stakingContract, uint256 _rewardRate, uint256 _rewardDuration) ERC721(_name, _symbol) {
        stakingContract = _stakingContract;
        rewardRate = _rewardRate;
        rewardDuration = _rewardDuration;
    }

    function stake(uint256 _amount) public {
        require(msg.sender == stakingContract, "Only the staking contract can call this function");
        require(_amount > 0, "Invalid amount");
        require(totalStaked + _amount <= totalSupply, "Insufficient balance");
        _mint(msg.sender, _amount);
        totalStaked += _amount;
    }

    function unstake(uint256 _amount) public {
        require(msg.sender == stakingContract, "Only the staking contract can call this function");
        require(_amount > 0, "Invalid amount");
        require(totalStaked - _amount >= 0, "Insufficient balance");
        _burn(msg.sender, _amount);
        totalStaked -= _amount;
    }

    function claimRewards() public {
        require(msg.sender == stakingContract, "Only the staking contract can call this function");
        uint256 reward = (totalStaked * rewardRate * (block.timestamp - rewardDuration)) / (totalSupply * rewardDuration);
        _transfer(msg.sender, stakingContract, reward);
    }
}