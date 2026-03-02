// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Minimal gas ERC20
contract MinimalGasERC20 {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    uint256 public totalSupply;

    event Transfer(address indexed, address indexed, uint256);
    event Approval(address indexed, address indexed, uint256);

    constructor(uint256 s) {
        totalSupply = s;
        balanceOf[msg.sender] = s;
    }

    function transfer(address t, uint256 v) external returns (bool) {
        balanceOf[msg.sender] -= v;
        unchecked { balanceOf[t] += v; }
        emit Transfer(msg.sender, t, v);
        return true;
    }

    function approve(address s, uint256 v) external returns (bool) {
        allowance[msg.sender][s] = v;
        emit Approval(msg.sender, s, v);
        return true;
    }

    function transferFrom(address f, address t, uint256 v) external returns (bool) {
        allowance[f][msg.sender] -= v;
        balanceOf[f] -= v;
        unchecked { balanceOf[t] += v; }
        emit Transfer(f, t, v);
        return true;
    }
}
