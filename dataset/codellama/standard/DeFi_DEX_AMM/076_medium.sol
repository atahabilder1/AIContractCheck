// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

contract DEX {
    address public owner;
    address public token;
    uint256 public liquidity;
    uint256 public slippageProtection;
    uint256 public swapFee;
    mapping(address => uint256) public balances;
    mapping(address => uint256) public allowances;
    mapping(address => bool) public isLP;

    constructor(address _token) {
        owner = msg.sender;
        token = _token;
        liquidity = 0;
        slippageProtection = 0;
        swapFee = 0;
    }

    function addLiquidity(uint256 _amount) public {
        require(msg.sender == owner, "Only owner can add liquidity");
        balances[msg.sender] += _amount;
        liquidity += _amount;
        isLP[msg.sender] = true;
    }

    function removeLiquidity(uint256 _amount) public {
        require(isLP[msg.sender], "Only liquidity providers can remove liquidity");
        balances[msg.sender] -= _amount;
        liquidity -= _amount;
        isLP[msg.sender] = false;
    }

    function swap(uint256 _amount, address _recipient) public {
        require(msg.sender == owner, "Only owner can swap");
        require(balances[msg.sender] >= _amount, "Insufficient balance");
        balances[msg.sender] -= _amount;
        balances[_recipient] += _amount;
        slippageProtection += swapFee;
    }

    function getLiquidity() public view returns (uint256) {
        return liquidity;
    }

    function getSlippageProtection() public view returns (uint256) {
        return slippageProtection;
    }

    function getSwapFee() public view returns (uint256) {
        return swapFee;
    }

    function getBalance(address _address) public view returns (uint256) {
        return balances[_address];
    }

    function getAllowance(address _address) public view returns (uint256) {
        return allowances[_address];
    }
}