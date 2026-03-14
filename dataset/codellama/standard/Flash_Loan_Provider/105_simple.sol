// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract FlashLoan {
    address private owner;
    mapping(address => uint256) private balances;
    uint256 private fee;

    constructor(uint256 _fee) {
        owner = msg.sender;
        fee = _fee;
    }

    function lend(uint256 _amount) public {
        require(_amount > 0, "Invalid amount");
        require(balances[msg.sender] >= _amount, "Insufficient balance");

        balances[msg.sender] -= _amount;
        balances[owner] += _amount;

        emit LoanMade(_amount);
    }

    function repay(uint256 _amount) public {
        require(_amount > 0, "Invalid amount");
        require(balances[msg.sender] >= _amount, "Insufficient balance");

        balances[msg.sender] -= _amount;
        balances[owner] += _amount;

        emit LoanRepaid(_amount);
    }

    function getBalance(address _owner) public view returns (uint256) {
        return balances[_owner];
    }

    function getFee() public view returns (uint256) {
        return fee;
    }

    event LoanMade(uint256 amount);
    event LoanRepaid(uint256 amount);
}