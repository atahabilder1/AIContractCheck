// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";

contract FlashLoanProvider is Ownable {
    struct LiquidityProvider {
        uint256 balance;
        uint256 feeShare;
    }

    mapping(address => LiquidityProvider) public liquidityProviders;
    address[] public providerList;

    event LiquidityAdded(address indexed provider, uint256 amount);
    event LiquidityWithdrawn(address indexed provider, uint256 amount);
    event FlashLoanTaken(address indexed borrower, uint256 amount);
    event FeesDistributed(uint256 totalFees);

    function addLiquidity(uint256 amount) public {
        require(amount > 0, "Amount must be greater than zero");
        IERC20(msg.sender).transferFrom(msg.sender, address(this), amount);
        if (liquidityProviders[msg.sender].balance == 0) {
            providerList.push(msg.sender);
        }
        liquidityProviders[msg.sender].balance += amount;
        liquidityProviders[msg.sender].feeShare = 0;
        emit LiquidityAdded(msg.sender, amount);
    }

    function withdrawLiquidity(uint256 amount) public {
        require(liquidityProviders[msg.sender].balance >= amount, "Insufficient balance");
        IERC20(msg.sender).transfer(msg.sender, amount);
        liquidityProviders[msg.sender].balance -= amount;
        emit LiquidityWithdrawn(msg.sender, amount);
    }

    function takeFlashLoan(uint256 amount) public {
        require(amount > 0, "Amount must be greater than zero");
        require(liquidityProviders[msg.sender].balance >= amount, "Insufficient liquidity");
        IERC20(msg.sender).transfer(msg.sender, amount);
        emit FlashLoanTaken(msg.sender, amount);
    }

    function distributeFees() public onlyOwner {
        uint256 totalFees = 0;
        for (uint256 i = 0; i < providerList.length; i++) {
            address provider = providerList[i];
            uint256 fee = liquidityProviders[provider].balance / 100; // Example fee distribution
            liquidityProviders[provider].feeShare += fee;
            totalFees += fee;
        }
        for (uint256 i = 0; i < providerList.length; i++) {
            address provider = providerList[i];
            IERC20(provider).transfer(provider, liquidityProviders[provider].feeShare);
            liquidityProviders[provider].feeShare = 0;
        }
        emit FeesDistributed(totalFees);
    }
}