// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DeFiStaking {
    IERC20 public stakingToken;
    mapping(address => uint) public stakedAmounts;

    constructor(IERC20 _stakingToken) {
        stakingToken = _stakingToken;
    }

    function stakeTokens(uint _amount) external {
        require(_amount > 0, "Amount must be greater than zero");
        stakingToken.transferFrom(msg.sender, address(this), _amount);
        stakedAmounts[msg.sender] += _amount;
    }

    function withdrawTokens() external {
        uint amount = stakedAmounts[msg.sender];
        require(amount > 0, "No tokens to withdraw");
        stakingToken.transfer(msg.sender, amount);
        stakedAmounts[msg.sender] = 0;
    }
}