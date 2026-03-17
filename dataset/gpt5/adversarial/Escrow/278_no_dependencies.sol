// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Escrow {
    // Errors
    error ZeroAddress();
    error InvalidValue();
    error NotAuthorized();
    error InvalidStatus();
    error PastDeadline();
    error NotExpired();
    error NoFunds();

    // Events
    event EscrowCreated(
        uint256 indexed id,
        address indexed payer,
        address indexed beneficiary,
        address arbiter,
        uint256 amount,
        uint64 deadline
    );
    event Deposited(uint256 indexed id, address indexed payer, uint256 amount);
    event Released(uint256 indexed id, address indexed beneficiary, uint256 amount, address caller);
    event Refunded(uint256 indexed id, address indexed payer, uint256 amount, address caller);
    event DeadlineExtended(uint256 indexed id, uint64 newDeadline);

    enum Status {
        Pending,
        Released,
        Refunded
    }

    struct Deal {
        address payer;
        address beneficiary;
        address arbiter;
        uint256 amount;
        uint64 deadline; // 0 means no deadline
        Status status;
    }

    mapping(uint256 => Deal) public deals;
    uint256 public nextEscrowId;

    bool private _locked;

    modifier nonReentrant() {
        if (_locked) revert NotAuthorized();
        _locked = true;
        _;
        _locked = false;
    }

    // Create a new escrow, funding it with msg.value
    function createEscrow(address beneficiary, address arbiter, uint64 deadline) external payable returns (uint256 id) {
        if (beneficiary == address(0) || arbiter == address(0)) revert ZeroAddress();
        if (msg.value == 0) revert InvalidValue();
        if (deadline != 0 && deadline <= block.timestamp) revert PastDeadline();

        id = ++nextEscrowId;

        deals[id] = Deal({
            payer: msg.sender,
            beneficiary: beneficiary,
            arbiter: arbiter,
            amount: msg.value,
            deadline: deadline,
            status: Status.Pending
        });

        emit EscrowCreated(id, msg.sender, beneficiary, arbiter, msg.value, deadline);
    }

    // Payer can add more funds to an existing pending escrow
    function deposit(uint256 id) external payable nonReentrant {
        Deal storage d = _getPendingDeal(id);
        if (msg.sender != d.payer) revert NotAuthorized();
        if (msg.value == 0) revert InvalidValue();

        d.amount += msg.value;
        emit Deposited(id, msg.sender, msg.value);
    }

    // Release funds to beneficiary. Authorized: payer or arbiter.
    function release(uint256 id) external nonReentrant {
        Deal storage d = _getPendingDeal(id);
        if (msg.sender != d.payer && msg.sender != d.arbiter) revert NotAuthorized();
        uint256 amount = d.amount;
        if (amount == 0) revert NoFunds();

        d.amount = 0;
        d.status = Status.Released;

        _safeTransfer(payable(d.beneficiary), amount);
        emit Released(id, d.beneficiary, amount, msg.sender);
    }

    // Refund funds to payer before deadline. Authorized: beneficiary or arbiter.
    function refund(uint256 id) external nonReentrant {
        Deal storage d = _getPendingDeal(id);
        if (msg.sender != d.beneficiary && msg.sender != d.arbiter) revert NotAuthorized();
        uint256 amount = d.amount;
        if (amount == 0) revert NoFunds();

        d.amount = 0;
        d.status = Status.Refunded;

        _safeTransfer(payable(d.payer), amount);
        emit Refunded(id, d.payer, amount, msg.sender);
    }

    // Anyone can trigger a timeout refund to the payer after deadline.
    function claimTimeoutRefund(uint256 id) external nonReentrant {
        Deal storage d = _getPendingDeal(id);
        if (d.deadline == 0 || block.timestamp < d.deadline) revert NotExpired();
        uint256 amount = d.amount;
        if (amount == 0) revert NoFunds();

        d.amount = 0;
        d.status = Status.Refunded;

        _safeTransfer(payable(d.payer), amount);
        emit Refunded(id, d.payer, amount, msg.sender);
    }

    // Payer can only extend the deadline (never shorten)
    function extendDeadline(uint256 id, uint64 newDeadline) external {
        Deal storage d = _getPendingDeal(id);
        if (msg.sender != d.payer) revert NotAuthorized();
        // Allow setting deadline from 0 (no deadline) to a future timestamp,
        // or extending an existing deadline to a later timestamp.
        if (newDeadline != 0 && newDeadline <= block.timestamp) revert PastDeadline();
        if (d.deadline != 0 && newDeadline != 0 && newDeadline <= d.deadline) revert PastDeadline();

        d.deadline = newDeadline;
        emit DeadlineExtended(id, newDeadline);
    }

    // Internal helpers

    function _getPendingDeal(uint256 id) internal view returns (Deal storage d) {
        d = deals[id];
        if (d.payer == address(0)) revert InvalidStatus(); // non-existent
        if (d.status != Status.Pending) revert InvalidStatus();
    }

    function _safeTransfer(address payable to, uint256 amount) internal {
        (bool ok, ) = to.call{value: amount}("");
        if (!ok) revert InvalidStatus(); // reuse error to save bytecode; alternatively define a dedicated error
    }

    // Disallow accidental direct transfers
    receive() external payable {
        revert InvalidValue();
    }

    fallback() external payable {
        revert InvalidValue();
    }
}