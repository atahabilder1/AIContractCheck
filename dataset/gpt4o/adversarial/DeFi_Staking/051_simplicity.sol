// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract SimpleStaking {
    mapping(address => uint256) public balances;
    uint256 public totalStaked;
    uint256 public rewardRate = 100; // 10% reward
    uint256 public constant RATE_DIVISOR = 1000; // Divisor for reward rate

    function stake() external payable {
        require(msg.value > 0, "Must stake more than 0");
        balances[msg.sender] += msg.value;
        totalStaked += msg.value;
    }

    function withdraw(uint256 amount) external {
        require(balances[msg.sender] >= amount, "Insufficient balance");
        uint256 reward = (amount * rewardRate) / RATE_DIVISOR;
        balances[msg.sender] -= amount;
        totalStaked -= amount;
        payable(msg.sender).transfer(amount + reward);
    }

    function contractBalance() external view returns (uint256) {
        return address(this).balance;
    }
}