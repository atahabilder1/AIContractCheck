// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Proxy {
    address public implementation;

    constructor(address _implementation) {
        implementation = _implementation;
    }

    fallback() external payable {
        address impl = implementation;
        require(impl != address(0), "Implementation contract required");
        assembly {
            let ptr := mload(0x40)
            calldatacopy(ptr, 0, calldatasize())
            let result := delegatecall(gas(), impl, ptr, calldatasize(), 0, 0)
            let size := returndatasize()
            returndatacopy(ptr, 0, size)
            switch result
            case 0 { revert(ptr, size) }
            default { return(ptr, size) }
        }
    }
}

contract Upgradeable {
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    function upgradeTo(address newImplementation) external {
        require(msg.sender == owner, "Only owner can upgrade");
        assembly {
            sstore(0, newImplementation)
        }
    }
}