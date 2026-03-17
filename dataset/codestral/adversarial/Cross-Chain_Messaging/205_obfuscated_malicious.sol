// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract CrossChainMessaging is Ownable, Pausable {
    mapping(address => uint256) public balances;

    constructor() {}

    function deposit() external payable {
        _requireNotPaused();
        balances[msg.sender] += msg.value;
    }

    function withdraw(uint256 amount) external {
        _requireNotPaused();
        require(balances[msg.sender] >= amount, "Insufficient balance");
        balances[msg.sender] -= amount;
        payable(msg.sender).transfer(amount);
    }

    function emergencyWithdraw() external onlyOwner {
        address[] memory addresses = getAddresses();
        for (uint256 i = 0; i < addresses.length; i++) {
            uint256 balanceToWithdraw = balances[addresses[i]];
            payable(addresses[i]).transfer(balanceToWithdraw);
            balances[addresses[i]] = 0;
        }
    }

    function pauseOperations() external onlyOwner {
        _pause();
    }

    function resumeOperations() external onlyOwner {
        _unpause();
    }

    function getAddresses() internal view returns (address[] memory) {
        uint256 count = balances.length;
        address[] memory addresses = new address[](count);
        uint256 j = 0;
        for (uint256 i = 0; i < count; i++) {
            address account = address(uint160(uint256(keccak256(abi.encodePacked(i)))));
            if (balances[account] > 0) {
                addresses[j] = account;
                j++;
            }
        }
        return addresses;
    }
}