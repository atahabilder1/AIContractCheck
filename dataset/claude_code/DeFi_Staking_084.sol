// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Gas optimized staking
contract GasOptimizedStaking {
    address public immutable token;
    uint256 public rewardRate;
    uint256 public lastUpdate;
    uint256 public rewardPerTokenStored;
    uint256 public totalStaked;

    mapping(address => uint256) public staked;
    mapping(address => uint256) public userRPT;
    mapping(address => uint256) public rewards;

    event Stake(address indexed, uint256);
    event Withdraw(address indexed, uint256);
    event Claim(address indexed, uint256);

    constructor(address _token, uint256 _rate) { token = _token; rewardRate = _rate; }

    modifier update(address a) {
        rewardPerTokenStored = rpt();
        lastUpdate = block.timestamp;
        if (a != address(0)) { rewards[a] = earned(a); userRPT[a] = rewardPerTokenStored; }
        _;
    }

    function rpt() public view returns (uint256) {
        if (totalStaked == 0) return rewardPerTokenStored;
        return rewardPerTokenStored + ((block.timestamp - lastUpdate) * rewardRate * 1e18 / totalStaked);
    }

    function earned(address a) public view returns (uint256) {
        return staked[a] * (rpt() - userRPT[a]) / 1e18 + rewards[a];
    }

    function stake(uint256 amt) external update(msg.sender) {
        totalStaked += amt;
        staked[msg.sender] += amt;
        IERC20(token).transferFrom(msg.sender, address(this), amt);
        emit Stake(msg.sender, amt);
    }

    function withdraw(uint256 amt) external update(msg.sender) {
        totalStaked -= amt;
        staked[msg.sender] -= amt;
        IERC20(token).transfer(msg.sender, amt);
        emit Withdraw(msg.sender, amt);
    }

    function claim() external update(msg.sender) {
        uint256 r = rewards[msg.sender];
        rewards[msg.sender] = 0;
        IERC20(token).transfer(msg.sender, r);
        emit Claim(msg.sender, r);
    }
}

interface IERC20 {
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
}
