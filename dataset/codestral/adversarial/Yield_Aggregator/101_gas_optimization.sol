// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function transferFrom(address sender, address recipient, uint amount) external returns (bool);
}

contract YieldAggregator {
    mapping(address => uint) public userBalances;

    function deposit(address tokenAddress, uint amount) public {
        IERC20(tokenAddress).transferFrom(msg.sender, address(this), amount);
        userBalances[msg.sender] += amount;
    }

    function withdraw(uint amount) public {
        require(userBalances[msg.sender] >= amount, "Insufficient balance");
        IERC20(tokenAddress).transferFrom(address(this), msg.sender, amount);
        userBalances[msg.sender] -= amount;
    }
}