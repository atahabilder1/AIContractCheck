// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract WrappedEth {
    string public constant name = "Wrapped Ethereum";
    string public constant symbol = "WETH";
    uint8 public constant decimals = 18;

    mapping(address => uint) private balances;

    event Deposit(address indexed _from, uint _value);
    event Withdrawal(address indexed _to, uint _value);

    receive() external payable {
        deposit();
    }

    function deposit() public payable {
        balances[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    function withdraw(uint _amount) public {
        require(_amount <= balances[msg.sender], "Insufficient balance");
        balances[msg.sender] -= _amount;
        payable(msg.sender).transfer(_amount);
        emit Withdrawal(msg.sender, _amount);
    }

    function balanceOf(address _owner) public view returns (uint) {
        return balances[_owner];
    }
}