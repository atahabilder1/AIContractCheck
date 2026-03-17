// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    modifier nonReentrant() {
        require(_status != _ENTERED, "REENTRANCY");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
}

contract MilestoneEscrow is ReentrancyGuard {
    enum Status {
        Active,
        Completed,
        Cancelled
    }

    struct Milestone {
        string description;
        uint256 amount;
        bool approved;
        bool released;
        uint256 approvedAt;
        uint256 releasedAt;
    }

    address public immutable client;
    address public immutable freelancer;

    Status public status;

    Milestone[] private _milestones;
    uint256 public totalAmount;
    uint256 public totalReleased;

    event Deposited(address indexed from, uint256 amount);
    event MilestoneApproved(uint256 indexed index, uint256 amount, uint256 timestamp);
    event MilestoneReleased(uint256 indexed index, address indexed to, uint256 amount, uint256 timestamp);
    event SurplusWithdrawn(uint256 amount);
    event EscrowCancelled(uint256 refundedAmount);
    event EscrowCompleted(uint256 totalReleased);

    error NotClient();
    error NotFreelancer();
    error NotActive();
    error InvalidMilestone();
    error AlreadyApproved();
    error AlreadyReleased();
    error InsufficientFunding();
    error NothingToWithdraw();
    error InvalidInput();
    error CancelledOrCompleted();

    modifier onlyClient() {
        if (msg.sender != client) revert NotClient();
        _;
    }

    modifier onlyFreelancer() {
        if (msg.sender != freelancer) revert NotFreelancer();
        _;
    }

    modifier isActive() {
        if (status != Status.Active) revert NotActive();
        _;
    }

    constructor(
        address _client,
        address _freelancer,
        string[] memory descriptions,
        uint256[] memory amounts
    ) {
        if (_client == address(0) || _freelancer == address(0)) revert InvalidInput();
        if (descriptions.length == 0 || descriptions.length != amounts.length) revert InvalidInput();

        client = _client;
        freelancer = _freelancer;
        status = Status.Active;

        uint256 len = amounts.length;
        for (uint256 i = 0; i < len; i++) {
            if (amounts[i] == 0) revert InvalidInput();
            _milestones.push(
                Milestone({
                    description: descriptions[i],
                    amount: amounts[i],
                    approved: false,
                    released: false,
                    approvedAt: 0,
                    releasedAt: 0
                })
            );
            totalAmount += amounts[i];
        }
    }

    receive() external payable {
        // Accept ETH (e.g., via simple transfer). Anyone can send, but only client can withdraw surplus/refund.
        emit Deposited(msg.sender, msg.value);
    }

    function deposit() external payable onlyClient isActive {
        if (msg.value == 0) revert InvalidInput();
        emit Deposited(msg.sender, msg.value);
    }

    function milestonesCount() external view returns (uint256) {
        return _milestones.length;
    }

    function getMilestone(uint256 index)
        external
        view
        returns (
            string memory description,
            uint256 amount,
            bool approved,
            bool released,
            uint256 approvedAt,
            uint256 releasedAt
        )
    {
        if (index >= _milestones.length) revert InvalidMilestone();
        Milestone memory m = _milestones[index];
        return (m.description, m.amount, m.approved, m.released, m.approvedAt, m.releasedAt);
    }

    function remainingRequired() public view returns (uint256) {
        if (status != Status.Active) return 0;
        return totalAmount - totalReleased;
    }

    function surplus() public view returns (uint256) {
        uint256 needed = remainingRequired();
        uint256 bal = address(this).balance;
        if (bal > needed) {
            return bal - needed;
        }
        return 0;
    }

    function approveAndRelease(uint256 index) external onlyClient isActive nonReentrant {
        if (index >= _milestones.length) revert InvalidMilestone();
        Milestone storage m = _milestones[index];
        if (m.approved) revert AlreadyApproved();
        if (m.released) revert AlreadyReleased();
        if (address(this).balance < m.amount) revert InsufficientFunding();

        // Approve
        m.approved = true;
        m.approvedAt = block.timestamp;
        emit MilestoneApproved(index, m.amount, m.approvedAt);

        // Release
        m.released = true;
        m.releasedAt = block.timestamp;
        totalReleased += m.amount;

        (bool ok, ) = payable(freelancer).call{value: m.amount}("");
        require(ok, "TRANSFER_FAILED");

        emit MilestoneReleased(index, freelancer, m.amount, m.releasedAt);

        // Complete if all released
        if (totalReleased == totalAmount) {
            status = Status.Completed;
            emit EscrowCompleted(totalReleased);
        }
    }

    function withdrawSurplus(uint256 amount) external onlyClient nonReentrant {
        uint256 s = surplus();
        if (amount == 0 || amount > s) revert NothingToWithdraw();

        (bool ok, ) = payable(client).call{value: amount}("");
        require(ok, "TRANSFER_FAILED");
        emit SurplusWithdrawn(amount);
    }

    function withdrawAllSurplus() external onlyClient nonReentrant {
        uint256 s = surplus();
        if (s == 0) revert NothingToWithdraw();

        (bool ok, ) = payable(client).call{value: s}("");
        require(ok, "TRANSFER_FAILED");
        emit SurplusWithdrawn(s);
    }

    function cancelEscrow() external onlyClient isActive nonReentrant {
        status = Status.Cancelled;
        uint256 bal = address(this).balance;

        if (bal > 0) {
            (bool ok, ) = payable(client).call{value: bal}("");
            require(ok, "TRANSFER_FAILED");
        }

        emit EscrowCancelled(bal);
    }

    // Freelancer can withdraw any stray funds only after completion (e.g., accidental tips left)
    function withdrawAfterCompletion() external onlyFreelancer nonReentrant {
        if (status != Status.Completed) revert CancelledOrCompleted();
        uint256 bal = address(this).balance;
        if (bal == 0) revert NothingToWithdraw();
        (bool ok, ) = payable(freelancer).call{value: bal}("");
        require(ok, "TRANSFER_FAILED");
    }
}