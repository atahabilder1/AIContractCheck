// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract AMM {
    address public token;
    address public bondingCurve;

    constructor(address _token, address _bondingCurve) public {
        token = _token;
        bondingCurve = _bondingCurve;
    }

    function buy(uint256 _amount) public {
        require(_amount > 0, "Invalid amount");
        require(msg.value >= _amount, "Insufficient balance");

        // Calculate the bonding curve price
        uint256 price = bondingCurve.getPrice(_amount);

        // Transfer the tokens to the buyer
        token.transfer(msg.sender, _amount);

        // Refund the remaining balance
        msg.sender.transfer(msg.value - _amount);
    }

    function sell(uint256 _amount) public {
        require(_amount > 0, "Invalid amount");
        require(token.balanceOf(msg.sender) >= _amount, "Insufficient balance");

        // Calculate the bonding curve price
        uint256 price = bondingCurve.getPrice(_amount);

        // Transfer the tokens to the seller
        token.transfer(msg.sender, _amount);

        // Refund the remaining balance
        msg.sender.transfer(msg.value - _amount);
    }
}