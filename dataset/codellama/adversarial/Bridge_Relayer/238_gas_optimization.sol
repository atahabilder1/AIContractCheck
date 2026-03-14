// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract BridgeRelayer {
    mapping(address => uint256) public balances;

    function deposit(address _tokenAddress, uint256 _amount) external {
        require(msg.sender == _tokenAddress, "Only the token contract can deposit");
        balances[_tokenAddress] = _amount;
    }

    function withdraw(uint256 _amount) external {
        require(balances[msg.sender] >= _amount, "Insufficient balance");
        balances[msg.sender] -= _amount;
    }
}