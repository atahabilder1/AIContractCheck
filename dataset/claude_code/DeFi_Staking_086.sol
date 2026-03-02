// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Minimal staking implementation
contract MinimalStaking {
    address public token;
    uint256 public totalStaked;
    uint256 public rewardRate;
    uint256 public lastUpdate;
    uint256 public rpt;

    mapping(address => uint256) public staked;
    mapping(address => uint256) public paid;
    mapping(address => uint256) public rewards;

    constructor(address _token) { token = _token; rewardRate = 1e15; }

    function update() internal {
        rpt = totalStaked == 0 ? rpt : rpt + (block.timestamp - lastUpdate) * rewardRate * 1e18 / totalStaked;
        lastUpdate = block.timestamp;
    }

    function updateUser(address u) internal {
        rewards[u] = staked[u] * (rpt - paid[u]) / 1e18 + rewards[u];
        paid[u] = rpt;
    }

    function stake(uint256 amt) external {
        update(); updateUser(msg.sender);
        totalStaked += amt;
        staked[msg.sender] += amt;
        IERC20(token).transferFrom(msg.sender, address(this), amt);
    }

    function withdraw(uint256 amt) external {
        update(); updateUser(msg.sender);
        totalStaked -= amt;
        staked[msg.sender] -= amt;
        IERC20(token).transfer(msg.sender, amt);
    }

    function claim() external {
        update(); updateUser(msg.sender);
        uint256 r = rewards[msg.sender];
        rewards[msg.sender] = 0;
        IERC20(token).transfer(msg.sender, r);
    }
}

interface IERC20 {
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
}
