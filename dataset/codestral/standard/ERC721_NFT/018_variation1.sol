// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract StakingNFT is ERC721, Ownable {
    IERC20 public rewardToken;
    mapping(uint256 => uint256) public stakedTokens;
    mapping(uint256 => uint256) public rewards;

    constructor(string memory name_, string memory symbol_) ERC721(name_, symbol_) {}

    function setRewardToken(IERC20 _rewardToken) external onlyOwner {
        rewardToken = _rewardToken;
    }

    function stake(uint256 tokenId) external {
        _transferFrom(msg.sender, address(this), tokenId);
        stakedTokens[tokenId] = block.timestamp;
    }

    function unstake(uint256 tokenId) external {
        require(stakedTokens[tokenId] > 0, "Token is not staked");
        uint256 timeStaked = block.timestamp - stakedTokens[tokenId];
        rewards[msg.sender] += (timeStaked * rewardToken.balanceOf(address(this))) / (7 days); // Assuming 1 week period
        _transferFrom(address(this), msg.sender, tokenId);
    }

    function claimRewards() external {
        uint256 amount = rewards[msg.sender];
        rewardToken.transfer(msg.sender, amount);
        rewards[msg.sender] = 0;
    }
}