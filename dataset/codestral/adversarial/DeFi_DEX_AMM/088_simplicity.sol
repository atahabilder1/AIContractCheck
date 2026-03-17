// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract SimpleDEX {
    uint public totalSupplyToken1;
    uint public totalSupplyToken2;
    mapping(address => uint) public balanceOfToken1;
    mapping(address => uint) public balanceOfToken2;

    constructor() {
        totalSupplyToken1 = 1000 * (10**18); // initial supply of Token1
        totalSupplyToken2 = 500 * (10**18); // initial supply of Token2
        balanceOfToken1[msg.sender] = totalSupplyToken1;
    }

    function swap(uint amount, bool tokenDirection) public {
        if (tokenDirection) { // Token1 to Token2
            require(balanceOfToken1[msg.sender] >= amount, "Not enough balance");
            balanceOfToken1[msg.sender] -= amount;
            balanceOfToken2[msg.sender] += amount * totalSupplyToken2 / totalSupplyToken1;
        } else { // Token2 to Token1
            require(balanceOfToken2[msg.sender] >= amount, "Not enough balance");
            balanceOfToken2[msg.sender] -= amount;
            balanceOfToken1[msg.sender] += amount * totalSupplyToken1 / totalSupplyToken2;
        }
    }
}