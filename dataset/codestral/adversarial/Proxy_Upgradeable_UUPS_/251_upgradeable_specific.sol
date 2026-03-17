// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Proxy {
    address public logicContractAddress;
    bytes32 private initializationHash;

    constructor(address _logicContractAddress, bytes memory _initData) {
        logicContractAddress = _logicContractAddress;
        initializationHash = keccak256(_initData);
        (bool success, ) = logicContractAddress.call(_initData);
        require(success, "Initialization failed");
    }

    fallback() external payable {
        address currentLogicContractAddress = getCurrentLogicContract();
        assembly {
            let ptr := mload(0x40)
            calldatacopy(ptr, 0, calldatasize())
            let result := delegatecall(gas(), currentLogicContractAddress, ptr, calldatasize(), 0, 0)
            returndatacopy(ptr, 0, returndatasize())
            switch result case 0 { revert(ptr, returndatasize()) } default { return(ptr, returndatasize()) }
        }
    }

    function getCurrentLogicContract() public view returns (address) {
        bytes32 currentInitializationHash = keccak256(abi.encodePacked("init", logicContractAddress));
        return (currentInitializationHash == initializationHash) ? logicContractAddress : address(0);
    }

    function upgradeTo(address newLogicContractAddress) public {
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, "init")
            mstore(add(ptr, 0x20), newLogicContractAddress)
            delegatecall(gas(), logicContractAddress, ptr, 0x40, 0, 0)
        }
        logicContractAddress = newLogicContractAddress;
    }
}