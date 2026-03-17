// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract GasOptimizedToken is ERC20 {
    using SafeMath for uint256;

    string private _name = "GasOptimizedToken";
    string private _symbol = "GOT";
    uint8 private _decimals = 18;
    uint256 private _totalSupply = 1000000e18; // 1,000,000 tokens with 18 decimals

    constructor() ERC20(_name, _symbol) {
        _mint(msg.sender, _totalSupply);
    }

    function transferFrom(address sender, address recipient, uint256 amount) external override returns (bool) {
        _transfer(sender, recipient, amount);
        return true;
    }
}