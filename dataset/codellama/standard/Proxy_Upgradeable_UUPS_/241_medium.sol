// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-solidity/contracts/proxy/UUPSProxy.sol";

contract UUPSUpgradeableERC20 is ERC20, UUPSProxy {
    address private _authorizedUpgrader;

    constructor(string memory name, string memory symbol) ERC20(name, symbol) UUPSProxy() {
        _authorizedUpgrader = msg.sender;
    }

    function _authorizeUpgrade(address newImplementation) internal override {
        require(msg.sender == _authorizedUpgrader, "Unauthorized upgrader");
        _setImplementation(newImplementation);
    }
}