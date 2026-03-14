// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IImplementation {
    function initialize() external;
    function upgradeTo(address newImplementation) external;
    function implementation() external view returns (address);
}

contract UUPSProxy {
    address private immutable implementation;

    constructor(address _implementation) {
        implementation = _implementation;
    }

    fallback() external payable {
        address impl = implementation;
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    receive() external payable {}
}

contract UUPSImplementation is IImplementation {
    address private owner;

    function initialize() external override {
        owner = msg.sender;
    }

    function upgradeTo(address newImplementation) external override {
        require(msg.sender == owner, "Only owner can upgrade the implementation");
        // Implementation upgrade logic
    }

    function implementation() external view override returns (address) {
        return address(this);
    }
}