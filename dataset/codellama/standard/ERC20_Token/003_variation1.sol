// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";

contract MyToken is ERC20 {
    uint256 private constant _totalSupply = 1_000_000_000 * 10 ** 18;

    constructor() ERC20("MyToken", "MYT") {
        _mint(msg.sender, _totalSupply);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(amount <= _totalSupply, "ERC20: transfer amount exceeds supply");
        super._beforeTokenTransfer(from, to, amount);
    }
}