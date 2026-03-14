```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title GovernanceToken
 * @dev A minimal ERC20 token for use as a governance token in a DAO.
 *      Includes basic ERC20 functionality and an owner-only minting function
 *      for initial distribution.
 */
contract GovernanceToken {
    string public name = "Hackathon DAO Token";
    string public symbol = "HDT";
    uint8 public decimals = 18;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(