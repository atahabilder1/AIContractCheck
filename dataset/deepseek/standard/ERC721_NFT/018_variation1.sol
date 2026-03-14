// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract StakingNFT is ERC721, ERC721Enumerable, ERC721Pausable, Ownable {
    using SafeMath for uint256;

    IERC20 public rewardToken;
    uint256 public rewardRate;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;
    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;

    struct Stake {
        uint256 stakeId;
        uint256 stakeTime;
    }

    mapping(address => Stake[]) public stakes;

    constructor(address _rewardToken, uint256 _rewardRate) ERC721("StakingNFT", "SNFT") {
        rewardToken = IERC20(_rewardToken);
        rewardRate = _rewardRate;
    }

    function stake(uint256 tokenId) public {
        require(_isApprovedOrOwner(msg.sender, tokenId), "ERC721: transfer caller is not owner nor approved");
        _safeMint(msg.sender, tokenId);
        stakes[msg.sender].push(Stake(tokenId, block.timestamp));
        updateReward(msg.sender);
    }

    function unstake(uint256 tokenId) public {
        require(_isApprovedOrOwner(msg.sender, tokenId), "ERC721: transfer caller is not owner nor approved");
        _burn(tokenId);
        for (uint256 i = 0; i < stakes[msg.sender].length; i++) {
            if (stakes[msg.sender][i].stakeId == tokenId) {
                stakes[msg.sender][i] = stakes[msg.sender][stakes[msg.sender].length - 1];
                stakes[msg.sender].pop();
                break;
            }
        }
        updateReward(msg.sender);
    }

    function earned(address account) public view returns (uint256) {
        uint256 _rewardPerTokenStored = rewardPerToken();
        return balanceOf(account).mul(rewardPerTokenStored - userRewardPerTokenPaid[account]).add(rewards[account]);
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalSupply() == 0) {
            return rewardPerTokenStored;
        }
        return rewardPerTokenStored.add(lastTimeRewardApplicable().sub(lastUpdateTime).mul(rewardRate).mul(1e18).div(totalSupply()));
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return block.timestamp < lastUpdateTime + 1 days ? block.timestamp : lastUpdateTime + 1 days;
    }

    function updateReward(address account) internal {
        uint256 _rewardPerTokenStored = rewardPerToken();
        rewardPerTokenStored = _rewardPerTokenStored;
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = _rewardPerTokenStored;
        }
    }

    function getStakes(address user) public view returns (Stake[] memory) {
        return stakes[user];
    }

    function withdrawReward(uint256 amount) public {
        require(amount <= rewards[msg.sender], "Insufficient reward amount");
        rewards[msg.sender] = rewards[msg.sender].sub(amount);
        rewardToken.transfer(msg.sender, amount);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal override(ERC721, ERC721Enumerable, ERC721Pausable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _burn(uint256 tokenId) internal override(ERC721, ERC721Enumerable, ERC721Pausable) {
        super._burn(tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}