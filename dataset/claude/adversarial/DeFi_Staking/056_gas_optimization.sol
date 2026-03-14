// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract StakingPool {
    uint256 public rewardRate;
    uint256 public totalStaked;
    uint256 public rewardPerTokenStored;
    uint256 public lastUpdateTime;

    mapping(address => uint256) public balances;
    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;

    address public immutable owner;
    address public immutable stakingToken;
    address public immutable rewardToken;

    error ZeroAmount();
    error NotOwner();
    error TransferFailed();

    constructor(address _stakingToken, address _rewardToken) {
        owner = msg.sender;
        stakingToken = _stakingToken;
        rewardToken = _rewardToken;
    }

    modifier updateReward(address account) {
        uint256 rpt = rewardPerToken();
        rewardPerTokenStored = rpt;
        lastUpdateTime = block.timestamp;
        if (account != address(0)) {
            rewards[account] = earned(account, rpt);
            userRewardPerTokenPaid[account] = rpt;
        }
        _;
    }

    function rewardPerToken() public view returns (uint256) {
        uint256 ts = totalStaked;
        if (ts == 0) return rewardPerTokenStored;
        unchecked {
            return rewardPerTokenStored + ((block.timestamp - lastUpdateTime) * rewardRate * 1e18 / ts);
        }
    }

    function earned(address account, uint256 rpt) internal view returns (uint256) {
        unchecked {
            return (balances[account] * (rpt - userRewardPerTokenPaid[account]) / 1e18) + rewards[account];
        }
    }

    function earned(address account) external view returns (uint256) {
        return earned(account, rewardPerToken());
    }

    function stake(uint256 amount) external updateReward(msg.sender) {
        if (amount == 0) revert ZeroAmount();
        unchecked { totalStaked += amount; }
        balances[msg.sender] += amount;
        _transferIn(stakingToken, amount);
    }

    function withdraw(uint256 amount) external updateReward(msg.sender) {
        if (amount == 0) revert ZeroAmount();
        unchecked { totalStaked -= amount; }
        balances[msg.sender] -= amount;
        _transferOut(stakingToken, amount);
    }

    function claim() external updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        if (reward == 0) revert ZeroAmount();
        rewards[msg.sender] = 0;
        _transferOut(rewardToken, reward);
    }

    function exit() external updateReward(msg.sender) {
        uint256 bal = balances[msg.sender];
        uint256 reward = rewards[msg.sender];
        balances[msg.sender] = 0;
        rewards[msg.sender] = 0;
        unchecked { totalStaked -= bal; }
        if (bal != 0) _transferOut(stakingToken, bal);
        if (reward != 0) _transferOut(rewardToken, reward);
    }

    function setRewardRate(uint256 rate) external updateReward(address(0)) {
        if (msg.sender != owner) revert NotOwner();
        rewardRate = rate;
    }

    function _transferIn(address token, uint256 amount) internal {
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, 0x23b872dd00000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 4), caller())
            mstore(add(ptr, 36), address())
            mstore(add(ptr, 68), amount)
            if iszero(call(gas(), token, 0, ptr, 100, ptr, 32)) { revert(0, 0) }
            if returndatasize() { if iszero(mload(ptr)) { revert(0, 0) } }
        }
    }

    function _transferOut(address token, uint256 amount) internal {
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, 0xa9059cbb00000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 4), caller())
            mstore(add(ptr, 36), amount)
            if iszero(call(gas(), token, 0, ptr, 68, ptr, 32)) { revert(0, 0) }
            if returndatasize() { if iszero(mload(ptr)) { revert(0, 0) } }
        }
    }
}