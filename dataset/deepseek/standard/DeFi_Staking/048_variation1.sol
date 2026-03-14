// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract LiquidStaking is ERC20, Ownable {
    struct Stake {
        uint256 amount;
        uint256 start;
    }

    mapping(address => Stake) public stakes;

    constructor() ERC20("stToken", "stT") {}

    function stake(uint256 amount) public {
        require(amount > 0, "Amount must be greater than zero");
        if (stakes[msg.sender].amount > 0) {
            uint256 reward = calculateReward(msg.sender);
            _mint(msg.sender, reward);
        }
        stakes[msg.sender] = Stake({amount: amount, start: block.timestamp});
        _mint(msg.sender, amount);
    }

    function unstake(uint256 amount) public {
        require(stakes[msg.sender].amount >= amount, "Insufficient balance");
        uint256 reward = calculateReward(msg.sender);
        _burn(msg.sender, amount);
        stakes[msg.sender].amount -= amount;
        if (stakes[msg.sender].amount == 0) {
            stakes[msg.sender].start = 0;
        }
        _mint(msg.sender, reward);
    }

    function calculateReward(address user) public view returns (uint256) {
        if (stakes[user].amount == 0) {
            return 0;
        }
        uint256 timeDiff = block.timestamp - stakes[user].start;
        return (stakes[user].amount * timeDiff) / 365 days; // Assuming 365 days per year for simplicity
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        require(stakes[msg.sender].amount >= amount, "Insufficient balance");
        _transfer(msg.sender, to, amount);
        return true;
    }
}