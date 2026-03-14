// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MySimpleToken is ERC20 {
    constructor() ERC20("MySimpleToken", "MST") {
        // Mint 1,000,000 tokens to the deployer
        // The value is 1,000,000 * (10 ** decimals), where decimals is typically 18.
        _mint(msg.sender, 1_000_000 * 10**18);
    }
}