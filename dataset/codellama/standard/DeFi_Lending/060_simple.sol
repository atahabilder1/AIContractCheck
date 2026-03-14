// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CollateralizedLending {
    address public owner;
    address public stablecoinAddress;
    uint public totalCollateral;
    uint public totalBorrows;
    mapping(address => uint) public userCollateral;
    mapping(address => uint) public userBorrows;

    constructor(address _stablecoinAddress) public {
        owner = msg.sender;
        stablecoinAddress = _stablecoinAddress;
        totalCollateral = 0;
        totalBorrows = 0;
    }

    function depositCollateral(uint _amount) public {
        require(msg.sender == owner, "Only the owner can deposit collateral");
        require(_amount > 0, "Invalid amount");
        totalCollateral += _amount;
        userCollateral[msg.sender] += _amount;
    }

    function withdrawCollateral(uint _amount) public {
        require(msg.sender == owner, "Only the owner can withdraw collateral");
        require(_amount > 0, "Invalid amount");
        require(userCollateral[msg.sender] >= _amount, "Insufficient collateral");
        totalCollateral -= _amount;
        userCollateral[msg.sender] -= _amount;
    }

    function borrow(uint _amount) public {
        require(msg.sender == owner, "Only the owner can borrow");
        require(_amount > 0, "Invalid amount");
        require(totalCollateral >= _amount, "Insufficient collateral");
        totalBorrows += _amount;
        userBorrows[msg.sender] += _amount;
    }

    function repay(uint _amount) public {
        require(msg.sender == owner, "Only the owner can repay");
        require(_amount > 0, "Invalid amount");
        require(userBorrows[msg.sender] >= _amount, "Insufficient borrows");
        totalBorrows -= _amount;
        userBorrows[msg.sender] -= _amount;
    }

    function getTotalCollateral() public view returns (uint) {
        return totalCollateral;
    }

    function getTotalBorrows() public view returns (uint) {
        return totalBorrows;
    }

    function getUserCollateral(address _user) public view returns (uint) {
        return userCollateral[_user];
    }

    function getUserBorrows(address _user) public view returns (uint) {
        return userBorrows[_user];
    }
}