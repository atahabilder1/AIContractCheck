// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/Proxy.sol";

contract SimpleUUPSProxy is Proxy {
    address public implementation;

    constructor(address initialImplementation) {
        implementation = initialImplementation;
    }

    function _delegate(address implementationAddress) internal override {
        assembly {
            // calldata is already loaded in memory at 0x00
            // call the implementation contract
            let result := delegatecall(gas(), implementationAddress, 0x00, calldatasize(), 0x00, 0x00)
            // copy return data if any
            let size := returndatasize()
            let ptr := mload(0x40) // free memory pointer
            // copy return data to the free memory pointer
            returndatacopy(ptr, 0x00, size)
            // return the data
            return(ptr, size)
        }
    }

    function upgradeTo(address newImplementation) public {
        require(msg.sender == owner(), "Only the owner can upgrade");
        implementation = newImplementation;
    }

    // This function is a placeholder for the actual owner management logic.
    // In a real-world scenario, you would use OpenZeppelin's Ownable or similar.
    function owner() public view virtual returns (address) {
        // Placeholder for owner address. Replace with actual owner logic.
        // For this simple example, we'll assume the deployer is the owner.
        return tx.origin; // Or a proper owner variable
    }
}