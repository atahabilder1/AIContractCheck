// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract OptimizedToken is ERC20 {
    using SafeMath for uint256;

    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {}

    function _transfer(address from, address to, uint256 amount) internal override {
        _balances[from] = _balances[from].sub(amount);
        _balances[to] = _balances[to].add(amount);
    }
}