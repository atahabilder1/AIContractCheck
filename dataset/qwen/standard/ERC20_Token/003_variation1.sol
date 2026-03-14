// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";

contract CappedToken is ERC20, ERC20Permit, ERC20Capped {
    uint256 private constant INITIAL_SUPPLY = 1_000_000_000 * 10**decimals();

    constructor() ERC20("CappedToken", "CTK") ERC20Permit("CappedToken") ERC20Capped(INITIAL_SUPPLY) {
        _mint(msg.sender, INITIAL_SUPPLY);
    }

    function _mint(address account, uint256 amount) internal virtual override(ERC20, ERC20Capped) {
        require(ERC20.totalSupply() + amount <= cap(), "ERC20Capped: cap exceeded");
        super._mint(account, amount);
    }
}