// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract UpgradeableContract is Initializable, UUPSUpgradeable, Pausable, Ownable {
    uint256 private _value;

    function initialize() public initializer {
        __Ownable_init();
        __Pausable_init();
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function setValue(uint256 newValue) external whenNotPaused {
        _value = newValue;
    }

    function getValue() external view returns (uint256) {
        return _value;
    }

    // Emergency function to withdraw all funds
    function emergencyWithdraw() external onlyOwner whenPaused {
        payable(owner()).transfer(address(this).balance);
    }

    // Emergency function to pause operations
    function pauseContract() external onlyOwner {
        _pause();
    }

    // Emergency function to unpause operations
    function unpauseContract() external onlyOwner {
        _unpause();
    }

    // Receive function to accept Ether
    receive() external payable {}

    // Fallback function to accept Ether
    fallback() external payable {}
}