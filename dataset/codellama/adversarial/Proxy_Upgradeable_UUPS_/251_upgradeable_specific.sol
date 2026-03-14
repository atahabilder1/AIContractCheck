// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-solidity/contracts/proxy/UUPS.sol";

contract MyProxy is UUPS {
    address public implementation;

    function initialize() public {
        implementation = address(this);
    }

    function upgradeTo(address newImplementation) public {
        implementation = newImplementation;
    }
}