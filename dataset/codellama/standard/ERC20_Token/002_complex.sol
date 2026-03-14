// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20VestingSchedule.sol";
import "@openzeppelin/contracts/governance/Governor.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";

contract MyToken is ERC20, ERC20VestingSchedule, Governor, Ownable {
    using Counters for Counters.Counter;
    using ECDSA for bytes32;
    using EIP712 for EIP712.Domain;

    Counters.Counter private _tokenIdCounter;

    constructor() ERC20("MyToken", "MYT") ERC20VestingSchedule(msg.sender) Governor() Ownable() {}

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20, ERC20VestingSchedule) {
        super._beforeTokenTransfer(from, to, amount);
        _approve(msg.sender, amount);
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) public onlyOwner {
        _burn(from, amount);
    }

    function _approve(address owner, uint256 amount) internal {
        _approvals[owner][msg.sender] = amount;
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(amount > 0, "amount must be greater than 0");
        require(balanceOf(from) >= amount, "balance must be greater than or equal to amount");
        require(balanceOf(to) + amount >= amount, "to balance must be greater than or equal to amount");
        _transfer(from, to, amount);
    }

    function _getSnapshot(uint256 blockNumber) internal view returns (uint256) {
        return _snapshots[blockNumber];
    }

    function _setSnapshot(uint256 blockNumber, uint256 value) internal {
        _snapshots[blockNumber] = value;
    }

    function _getSnapshots() internal view returns (uint256[] memory) {
        return _snapshots;
    }

    function _setSnapshots(uint256[] memory snapshots) internal {
        _snapshots = snapshots;
    }

    function _getSnapshotBlocks() internal view returns (uint256[] memory) {
        return _snapshotBlocks;
    }

    function _setSnapshotBlocks(uint256[] memory snapshotBlocks) internal {
        _snapshotBlocks = snapshotBlocks;
    }

    function _getVestingStartBlock() internal view returns (uint256) {
        return _vestingStartBlock;
    }

    function _setVestingStartBlock(uint256 vestingStartBlock) internal {
        _vestingStartBlock = vestingStartBlock;
    }

    function _getVestingEndBlock() internal view returns (uint256) {
        return _vestingEndBlock;
    }

    function _setVestingEndBlock(uint256 vestingEndBlock) internal {
        _vestingEndBlock = vestingEndBlock;
    }

    function _getVestingSchedule() internal view returns (uint256[] memory) {
        return _vestingSchedule;
    }

    function _setVestingSchedule(uint256[] memory vestingSchedule) internal {
        _vestingSchedule = vestingSchedule;
    }

    function _getVestingTotalSupply() internal view returns (uint256) {
        return _vestingTotalSupply;
    }

    function _setVestingTotalSupply(uint256 vestingTotalSupply) internal {
        _vestingTotalSupply = vestingTotalSupply;
    }

    function _getVestingBlocks() internal view returns (uint256[] memory) {
        return _vestingBlocks;
    }

    function _setVestingBlocks(uint256[] memory vestingBlocks) internal {
        _vestingBlocks = vestingBlocks;
    }

    function _getVestingAmount(address account) internal view returns (uint256) {
        return _vestingAmounts[account];
    }

    function _setVestingAmount(address account, uint256 vestingAmount) internal {
        _vestingAmounts[account] = vestingAmount;
    }

    function _getVestingBlock(uint256 blockNumber) internal view returns (uint256) {
        return _vestingBlocks[blockNumber];
    }

    function _setVestingBlock(uint256 blockNumber, uint256 vestingBlock) internal {
        _vestingBlocks[blockNumber] = vestingBlock;
    }

    function _getVestingBlocks() internal view returns (uint256[] memory) {
        return _vestingBlocks;
    }

    function _setVestingBlocks(uint256[] memory vestingBlocks) internal {
        _vestingBlocks = vestingBlocks;
    }

    function _getVestingAmount(address account, uint256 blockNumber) internal view returns (uint256) {
        return _vestingAmounts[account][blockNumber];
    }

    function _setVestingAmount(address account, uint256 blockNumber, uint256 vestingAmount) internal {
        _vestingAmounts[account][blockNumber] = vestingAmount;
    }

    function _getVestingAmounts(address account) internal view returns (uint256[] memory) {
        return _vestingAmounts[account];
    }

    function _setVestingAmounts(address account, uint256[] memory vestingAmounts) internal {
        _vestingAmounts[account] = vestingAmounts;
    }

    function _getVestingBlocks(address account) internal view returns (uint256[] memory) {
        return _vestingBlocks[account];
    }

    function _setVestingBlocks(address account, uint256[] memory vestingBlocks) internal {
        _vestingBlocks[account] = vestingBlocks;
    }
}