// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract MyToken is ERC20, UUPSUpgradeable, OwnableUpgradeable {
    /// @custom:storage-location void
    /// We use a storage gap for future upgradable variables.
    /// This allows us to add new state variables in future upgradeable versions
    /// without breaking existing deployments.
    uint256[50] private __gap;

    function initialize(string memory name, string memory symbol) public initializer {
        __ERC20_init(name, symbol);
        __Ownable_init();
    }

    function upgradeTo(address newImplementation) public virtual onlyOwner {
        _upgradeTo(newImplementation);
    }

    function _authorizeUpgrade(address newImplementation) internal override {
        require(OwnableUpgradeable.owner() == _msgSender(), "ERC1967: upgrade forbidden");
        super._authorizeUpgrade(newImplementation);
    }

    // You can add more ERC20 functionalities or custom logic here.
    // For example, a mint function:
    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}