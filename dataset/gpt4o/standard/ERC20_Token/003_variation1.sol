// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract CappedERC20 is ERC20, ERC20Permit, Ownable {
    uint256 private constant _cap = 1_000_000_000 * 10 ** 18; // 1 billion tokens with 18 decimals

    constructor(string memory name, string memory symbol) 
        ERC20(name, symbol) 
        ERC20Permit(name)
    {
        _mint(msg.sender, _cap);
    }

    function cap() public pure returns (uint256) {
        return _cap;
    }

    function _mint(address account, uint256 amount) internal override {
        require(totalSupply() + amount <= cap(), "CappedERC20: cap exceeded");
        super._mint(account, amount);
    }
}