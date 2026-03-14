// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Lending {
    address public borrower;
    address public lender;
    uint public amount;

    constructor(address _borrower, address _lender, uint _amount) public {
        borrower = _borrower;
        lender = _lender;
        amount = _amount;
    }

    function borrow() public {
        require(msg.sender == borrower, "Only borrower can borrow");
        require(amount > 0, "Invalid amount");
        lender.transfer(amount);
    }

    function repay() public {
        require(msg.sender == borrower, "Only borrower can repay");
        require(amount > 0, "Invalid amount");
        borrower.transfer(amount);
    }
}