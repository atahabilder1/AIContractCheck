// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract UpgradeableContract is UUPSUpgradeable, Ownable {
    address payable public owner;
    bool public paused = false;
    event FundsWithdrawn(address indexed recipient, uint256 amount);
    event Paused(bool isPaused);

    function initialize() public initializer {
        owner = payable(msg.sender);
    }

    function _authorizeUpgrade(address newImplementation) internal override {
        // Only the owner can upgrade the contract
        require(msg.sender == owner, "Only the owner can upgrade");
    }

    modifier whenNotPaused() {
        require(!paused, "Operation paused");
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    function setPaused(bool _paused) public onlyOwner {
        paused = _paused;
        emit Paused(_paused);
    }

    function withdrawAll() public onlyOwner whenNotPaused {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");
        (bool success, ) = owner.call{value: balance}("");
        require(success, "Withdrawal failed");
        emit FundsWithdrawn(owner, balance);
    }

    function receive() external payable {}

    function fallback() external payable {}
}