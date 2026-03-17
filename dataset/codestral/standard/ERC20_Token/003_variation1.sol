// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract GaslessToken is ERC20, ERC20Permit {
    uint256 public constant TOTAL_SUPPLY = 1e9 * (1 ether);

    constructor() ERC20("GaslessToken", "GLT") {
        _mint(msg.sender, TOTAL_SUPPLY);
    }
}