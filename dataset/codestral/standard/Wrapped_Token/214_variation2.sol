// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract WrappedToken is ERC20, Ownable {
    using SafeMath for uint256;

    IERC20 public underlyingToken;
    uint256 public unwrapFeePercentage = 1; // 1% fee on unwrapping
    mapping(address => uint256) private balanceSnapshot;
    mapping(address => uint256) private rewardDebt;
    uint256 private totalSupplySnapshot;

    constructor(IERC20 _underlyingToken) ERC20("WrappedToken", "WTOKEN") {
        underlyingToken = _underlyingToken;
    }

    function wrap() public returns (uint256 amount) {
        amount = underlyingToken.balanceOf(msg.sender);
        underlyingToken.transferFrom(msg.sender, address(this), amount);
        _mint(msg.sender, amount);
        balanceSnapshot[msg.sender] += amount;
        totalSupplySnapshot += amount;
    }

    function unwrap() public {
        uint256 amount = balanceOf(msg.sender);
        uint256 fee = amount.mul(unwrapFeePercentage).div(100);
        _burn(msg.sender, amount);
        distributeRewards(fee);
        underlyingToken.transfer(msg.sender, amount.sub(fee));
    }

    function distributeRewards(uint256 fee) private {
        uint256 totalSupply = totalSupplySnapshot;
        for (address holder in balanceSnapshot) {
            rewardDebt[holder] += balanceSnapshot[holder].mul(fee).div(totalSupply);
            uint256 rewards = rewardDebt[holder];
            if (rewards > 0) {
                underlyingToken.transfer(holder, rewards);
                rewardDebt[holder] = 0;
            }
        }
    }
}