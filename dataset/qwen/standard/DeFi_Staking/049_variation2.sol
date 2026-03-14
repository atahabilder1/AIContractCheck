// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract DynamicStaking {
    uint256 public constant BASE_APY = 5; // Base APY in percentage
    uint256 public constant MAX_APY = 20; // Max APY in percentage
    uint256 public constant MAX_TV_LOCKED = 1000000 ether; // Maximum TVL before APY stops increasing

    mapping(address => uint256) public stakedAmount;
    mapping(address => uint256) public lastClaimedTimestamp;
    uint256 public totalValueLocked;

    event Staked(address indexed user, uint256 amount);
    event Claimed(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);

    function stake(uint256 _amount) external {
        require(_amount > 0, "Amount must be greater than 0");
        stakedAmount[msg.sender] += _amount;
        totalValueLocked += _amount;
        lastClaimedTimestamp[msg.sender] = block.timestamp;
        emit Staked(msg.sender, _amount);
    }

    function claim() external {
        uint256 rewards = calculateRewards(msg.sender);
        require(rewards > 0, "No rewards to claim");
        lastClaimedTimestamp[msg.sender] = block.timestamp;
        payable(msg.sender).transfer(rewards);
        emit Claimed(msg.sender, rewards);
    }

    function withdraw(uint256 _amount) external {
        require(_amount > 0, "Amount must be greater than 0");
        require(stakedAmount[msg.sender] >= _amount, "Insufficient staked amount");
        claim(); // Claim rewards before withdrawing
        stakedAmount[msg.sender] -= _amount;
        totalValueLocked -= _amount;
        emit Withdrawn(msg.sender, _amount);
    }

    function calculateRewards(address _user) public view returns (uint256) {
        uint256 timePassed = block.timestamp - lastClaimedTimestamp[_user];
        uint256 apy = calculateCurrentAPY();
        uint256 rewards = (stakedAmount[_user] * apy * timePassed) / (365 days * 100);
        return rewards;
    }

    function calculateCurrentAPY() public view returns (uint256) {
        uint256 apy = BASE_APY + (totalValueLocked * (MAX_APY - BASE_APY)) / MAX_TV_LOCKED;
        return apy > MAX_APY ? MAX_APY : apy;
    }

    receive() external payable {}
}