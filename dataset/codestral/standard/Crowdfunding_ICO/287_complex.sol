// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract ICO is Ownable {
    using SafeMath for uint256;

    enum Tier { None, Whitelist1, Whitelist2 }
    enum Round { NotStarted, Round1, Round2 }

    struct User {
        address userAddress;
        Tier tier;
        uint256 tokensPurchased;
        uint256 vestingSchedule;
    }

    ERC20 public token;
    mapping(address => User) public users;

    Round public currentRound;
    uint256 public softCap;
    uint256 public hardCap;
    uint256 public round1Price;
    uint256 public round2Price;

    constructor(ERC20 _token, uint256 _softCap, uint256 _hardCap, uint256 _round1Price, uint256 _round2Price) {
        token = _token;
        softCap = _softCap;
        hardCap = _hardCap;
        round1Price = _round1Price;
        round2Price = _round2Price;
    }

    function whitelistUser(address user, Tier tier) external onlyOwner {
        users[user].tier = tier;
    }

    function buyTokens(uint256 amount, address recipient) external payable {
        require(currentRound != Round.NotStarted, "ICO has not started yet");
        require(users[msg.sender].tier != Tier.None, "You are not whitelisted");
        require(amount * getPrice() <= msg.value, "Insufficient funds sent");

        uint256 totalTokensPurchased = users[recipient].tokensPurchased + amount;
        require(totalTokensPurchased <= hardCap, "Hard cap exceeded");

        token.transfer(recipient, amount);
        users[recipient].tokensPurchased = totalTokensPurchased;
    }

    function startRound2() external onlyOwner {
        require(currentRound == Round.Round1 && address(token).balanceOf(address(this)) >= softCap, "Conditions for round 2 not met");
        currentRound = Round.Round2;
    }

    function updateVestingSchedule(address user, uint256 schedule) external onlyOwner {
        users[user].vestingSchedule = schedule;
    }

    function getPrice() private view returns (uint256) {
        return currentRound == Round.Round1 ? round1Price : round2Price;
    }
}