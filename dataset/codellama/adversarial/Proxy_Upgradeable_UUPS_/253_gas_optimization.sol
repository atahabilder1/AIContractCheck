// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Proxy {
    address public target;

    constructor(address _target) public {
        target = _target;
    }

    fallback() external {
        address _target = target;
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), _target, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            if eq(result, 0) {
                revert(0, returndatasize())
            }
            return(0, returndatasize())
        }
    }

    function upgrade(address _newTarget) public {
        target = _newTarget;
    }
}