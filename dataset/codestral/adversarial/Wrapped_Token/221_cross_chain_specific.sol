// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract WrappedToken {
    IERC20 public underlyingToken;
    string public name;
    string public symbol;
    uint8 public decimals;

    constructor(address _underlyingToken, string memory _name, string memory _symbol, uint8 _decimals) {
        underlyingToken = IERC20(_underlyingToken);
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
    }

    function wrap(uint amount) public returns (uint wrappedAmount) {
        underlyingToken.transferFrom(msg.sender, address(this), amount);
        wrappedAmount = amount;
        // Mint new wrapped tokens to the sender's account here
    }

    function unwrap(uint amount) public {
        // Burn wrapped tokens from the sender's account here
        msg.sender.transfer(underlyingToken.address, amount);
    }
}