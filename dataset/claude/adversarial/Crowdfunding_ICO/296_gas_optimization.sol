// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Crowdfunding {
    address public immutable owner;
    uint256 public immutable goal;
    uint256 public immutable deadline;
    uint256 public totalRaised;
    bool public claimed;

    mapping(address => uint256) public contributions;

    error NotOwner();
    error DeadlinePassed();
    error DeadlineNotPassed();
    error GoalNotReached();
    error GoalReached();
    error AlreadyClaimed();
    error ZeroAmount();
    error TransferFailed();
    error NothingToRefund();

    event Contributed(address indexed contributor, uint256 amount);
    event Claimed(uint256 amount);
    event Refunded(address indexed contributor, uint256 amount);

    constructor(uint256 _goal, uint256 _durationSeconds) {
        owner = msg.sender;
        goal = _goal;
        deadline = block.timestamp + _durationSeconds;
    }

    function contribute() external payable {
        if (block.timestamp >= deadline) revert DeadlinePassed();
        if (msg.value == 0) revert ZeroAmount();

        unchecked {
            contributions[msg.sender] += msg.value;
            totalRaised += msg.value;
        }

        emit Contributed(msg.sender, msg.value);
    }

    function claim() external {
        if (msg.sender != owner) revert NotOwner();
        if (block.timestamp < deadline) revert DeadlineNotPassed();
        if (totalRaised < goal) revert GoalNotReached();
        if (claimed) revert AlreadyClaimed();

        claimed = true;
        uint256 amount = totalRaised;

        emit Claimed(amount);

        (bool ok,) = owner.call{value: amount}("");
        if (!ok) revert TransferFailed();
    }

    function refund() external {
        if (block.timestamp < deadline) revert DeadlineNotPassed();
        if (totalRaised >= goal) revert GoalReached();

        uint256 amount = contributions[msg.sender];
        if (amount == 0) revert NothingToRefund();

        contributions[msg.sender] = 0;

        emit Refunded(msg.sender, amount);

        (bool ok,) = msg.sender.call{value: amount}("");
        if (!ok) revert TransferFailed();
    }

    receive() external payable {
        if (block.timestamp >= deadline) revert DeadlinePassed();
        unchecked {
            contributions[msg.sender] += msg.value;
            totalRaised += msg.value;
        }
        emit Contributed(msg.sender, msg.value);
    }
}