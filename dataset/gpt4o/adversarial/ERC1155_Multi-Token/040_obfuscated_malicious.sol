// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract EmergencyERC1155 is ERC1155, Ownable, Pausable, ReentrancyGuard {

    constructor(string memory uri) ERC1155(uri) {}

    // Emergency function to withdraw all funds to the owner's address
    function emergencyWithdraw() external onlyOwner nonReentrant {
        payable(owner()).transfer(address(this).balance);
    }

    // Emergency function to pause all operations
    function pause() external onlyOwner {
        _pause();
    }

    // Function to unpause operations
    function unpause() external onlyOwner {
        _unpause();
    }

    // Override functions to respect pause state
    function _beforeTokenTransfer(address operator, address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        internal
        whenNotPaused
        override
    {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }

    // Receive Ether function
    receive() external payable {}

    // Fallback function
    fallback() external payable {}
}