// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Hackathon staking - quick implementation
contract HackathonStaking {
    address public token;
    address public owner;
    uint256 public totalStaked;
    uint256 public rewardRate = 1e16;

    mapping(address => uint256) public staked;
    mapping(address => uint256) public lastClaim;

    constructor(address _token) {
        token = _token;
        owner = msg.sender;
    }

    function stake(uint256 amount) external {
        if (staked[msg.sender] > 0) {
            claim();
        }
        staked[msg.sender] += amount;
        totalStaked += amount;
        lastClaim[msg.sender] = block.timestamp;
        IERC20(token).transferFrom(msg.sender, address(this), amount);
    }

    function withdraw(uint256 amount) external {
        claim();
        staked[msg.sender] -= amount;
        totalStaked -= amount;
        IERC20(token).transfer(msg.sender, amount);
    }

    function claim() public {
        uint256 pending = pendingRewards(msg.sender);
        lastClaim[msg.sender] = block.timestamp;
        if (pending > 0) {
            IERC20(token).transfer(msg.sender, pending);
        }
    }

    function pendingRewards(address user) public view returns (uint256) {
        if (staked[user] == 0) return 0;
        uint256 duration = block.timestamp - lastClaim[user];
        return staked[user] * duration * rewardRate / 1e18;
    }

    function setRewardRate(uint256 rate) external {
        require(msg.sender == owner);
        rewardRate = rate;
    }
}

interface IERC20 {
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
}
