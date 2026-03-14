// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Timelock {
    uint256 public constant LOCK_DURATION = 7 days;

    address public immutable admin;
    address public immutable pendingAdmin;
    uint256 public immutable releaseTime;

    bool public paused;

    event AdminTransferred(address indexed previousAdmin, address indexed newAdmin);
    event Paused();
    event Unpaused();

    modifier onlyAdmin() {
        require(msg.sender == admin, "Timelock: caller is not the admin");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "Timelock: contract is paused");
        _;
    }

    modifier whenPaused() {
        require(paused, "Timelock: contract is not paused");
        _;
    }

    constructor(address _admin, uint256 _releaseTime) {
        admin = _admin;
        releaseTime = _releaseTime;
    }

    function transferAdmin(address newAdmin) external onlyAdmin {
        require(newAdmin != address(0), "Timelock: new admin is the zero address");
        address previousAdmin = admin;
        admin = newAdmin;
        emit AdminTransferred(previousAdmin, newAdmin);
    }

    function setPendingAdmin(address _pendingAdmin) external onlyAdmin {
        pendingAdmin = _pendingAdmin;
    }

    function acceptAdmin() external {
        require(msg.sender == pendingAdmin, "Timelock: caller is not the pending admin");
        address previousAdmin = admin;
        admin = pendingAdmin;
        pendingAdmin = address(0);
        emit AdminTransferred(previousAdmin, admin);
    }

    function pause() external onlyAdmin whenNotPaused {
        paused = true;
        emit Paused();
    }

    function unpause() external onlyAdmin whenPaused {
        paused = false;
        emit Unpaused();
    }

    function withdraw(address payable recipient, uint256 amount) external onlyAdmin {
        require(block.timestamp >= releaseTime, "Timelock: current time is before release time");
        recipient.transfer(amount);
    }
}