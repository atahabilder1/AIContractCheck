// Source: OpenZeppelin Contracts (GitHub)
// Original Path: mocks/docs/ERC20WithAutoMinerReward.sol
// License: MIT
// Collected: 2026-03-16T17:54:55.905413

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {ERC20} from "../../token/ERC20/ERC20.sol";

contract ERC20WithAutoMinerReward is ERC20 {
    constructor() ERC20("Reward", "RWD") {
        _mintMinerReward();
    }

    function _mintMinerReward() internal {
        _mint(block.coinbase, 1000);
    }

    function _update(address from, address to, uint256 value) internal virtual override {
        if (!(from == address(0) && to == block.coinbase)) {
            _mintMinerReward();
        }
        super._update(from, to, value);
    }
}
