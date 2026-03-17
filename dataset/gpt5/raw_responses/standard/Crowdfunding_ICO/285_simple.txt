// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Crowdfunding {
    address payable public immutable beneficiary;
    uint256 public immutable fundingGoal;
    uint64 public immutable deadline;

    uint256 public totalRaised;
    bool public ended;
    bool public successful;

    mapping(address => uint256) public contributions;

    bool private locked;

    event Contribution(address indexed contributor, uint256 amount, uint256 totalRaised);
    event Finalized(bool successful, uint256 totalRaised);
    event Refunded(address indexed contributor, uint256 amount);
    event Withdrawn(address indexed beneficiary, uint256 amount);

    modifier nonReentrant() {
        require(!locked, "Reentrancy");
        locked = true;
        _;
        locked = false;
    }

    constructor(uint256 goal, uint64 durationSeconds) {
        require(goal > 0, "Goal must be > 0");
        require(durationSeconds > 0, "Duration must be > 0");
        beneficiary = payable(msg.sender);
        fundingGoal = goal;
        deadline = uint64(block.timestamp + durationSeconds);
    }

    receive() external payable {
        _contribute();
    }

    function contribute() external payable {
        _contribute();
    }

    function _contribute() internal {
        require(!ended, "Campaign ended");
        require(block.timestamp < deadline, "Past deadline");
        require(msg.value > 0, "No ETH sent");

        contributions[msg.sender] += msg.value;
        totalRaised += msg.value;

        emit Contribution(msg.sender, msg.value, totalRaised);

        if (totalRaised >= fundingGoal) {
            _tryFinalize();
        }
    }

    function finalize() external {
        _tryFinalize();
        require(ended, "Too early to finalize");
    }

    function withdraw() external nonReentrant {
        _tryFinalize();
        require(ended && successful, "Not successful");
        require(msg.sender == beneficiary, "Only beneficiary");

        uint256 amount = address(this).balance;
        require(amount > 0, "Nothing to withdraw");

        (bool ok, ) = beneficiary.call{value: amount}("");
        require(ok, "Withdraw failed");

        emit Withdrawn(beneficiary, amount);
    }

    function claimRefund() external nonReentrant {
        _tryFinalize();
        require(ended && !successful, "Refunds not available");

        uint256 amount = contributions[msg.sender];
        require(amount > 0, "No contribution");

        contributions[msg.sender] = 0;

        (bool ok, ) = payable(msg.sender).call{value: amount}("");
        require(ok, "Refund failed");

        emit Refunded(msg.sender, amount);
    }

    function timeLeft() external view returns (uint64) {
        if (block.timestamp >= deadline) return 0;
        return uint64(deadline - block.timestamp);
    }

    function _tryFinalize() internal {
        if (!ended && (block.timestamp >= deadline || totalRaised >= fundingGoal)) {
            ended = true;
            successful = totalRaised >= fundingGoal;
            emit Finalized(successful, totalRaised);
        }
    }
}