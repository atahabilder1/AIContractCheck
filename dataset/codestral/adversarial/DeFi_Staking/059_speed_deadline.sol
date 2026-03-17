// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Staking {
    IERC20 public stakingToken;
    mapping(address => uint) public balances;

    constructor(address _stakingTokenAddress) {
        stakingToken = IERC20(_stakingTokenAddress);
    }

    function stake(uint amount) external {
        require(amount > 0, "Amount must be greater than zero");
        stakingToken.transferFrom(msg.sender, address(this), amount);
        balances[msg.sender] += amount;
    }

    function withdraw(uint amount) external {
        require(amount > 0, "Amount must be greater than zero");
        require(balances[msg.sender] >= amount, "Not enough staked tokens");
        stakingToken.transfer(msg.sender, amount);
        balances[msg.sender] -= amount;
    }
}