// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract ProxyAdmin is Ownable {
    function upgrade(address proxy, address newImplementation) external onlyOwner {
        TransparentUpgradeableProxy(proxy).upgradeTo(newImplementation);
    }
}

abstract contract UpgradeableContract is Initializable {
    // Contract logic here
}