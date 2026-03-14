// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract FlashLoanProvider {
    address private owner;
    mapping(address => uint) public balances;

    constructor() public {
        owner = msg.sender;
    }

    function flashLoan(address _receiver, uint _amount) public {
        require(msg.sender == owner, "Only the owner can call this function");
        require(_amount <= balances[msg.sender], "Insufficient balance");
        balances[msg.sender] -= _amount;
        balances[_receiver] += _amount;
    }

    function balanceOf(address _owner) public view returns (uint) {
        return balances[_owner];
    }
}