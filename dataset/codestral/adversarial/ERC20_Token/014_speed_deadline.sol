// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract DemoToken is ERC20, Ownable {
    constructor(uint256 initialSupply) ERC20("DemoToken", "DTK") {
        _mint(msg.sender, initialSupply);
    }
}