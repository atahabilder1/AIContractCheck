// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Escrow {
    enum State { Created, Funded, Disputed, Resolved, Completed, Refunded }

    struct Deal {
        address buyer;
        address seller;
        uint256 amount;
        uint256 released;
        uint256 deadline;
        State state;
    }

    address public arbiter;
    uint256 public dealCount;
    mapping(uint256 => Deal) public deals;

    event DealCreated(uint256 indexed dealId, address buyer, address seller, uint256 amount, uint256 deadline);
    event DealFunded(uint256 indexed dealId);
    event DisputeRaised(uint256 indexed dealId, address by);
    event PartialRelease(uint256 indexed dealId, uint256 amount);
    event DealCompleted(uint256 indexed dealId);
    event DealRefunded(uint256 indexed dealId);
    event DisputeResolved(uint256 indexed dealId, uint256 toSeller, uint256 toBuyer);

    modifier onlyArbiter() {
        require(msg.sender == arbiter, "Not arbiter");
        _;
    }

    modifier onlyBuyer(uint256 dealId) {
        require(msg.sender == deals[dealId].buyer, "Not buyer");
        _;
    }

    modifier inState(uint256 dealId, State expected) {
        require(deals[dealId].state == expected, "Invalid state");
        _;
    }

    constructor(address _arbiter) {
        require(_arbiter != address(0), "Invalid arbiter");
        arbiter = _arbiter;
    }

    function createDeal(address _seller, uint256 _duration) external payable returns (uint256) {
        require(msg.value > 0, "Must send funds");
        require(_seller != address(0) && _seller != msg.sender, "Invalid seller");
        require(_duration > 0, "Invalid duration");

        uint256 dealId = dealCount++;
        deals[dealId] = Deal({
            buyer: msg.sender,
            seller: _seller,
            amount: msg.value,
            released: 0,
            deadline: block.timestamp + _duration,
            state: State.Funded
        });

        emit DealCreated(dealId, msg.sender, _seller, msg.value, deals[dealId].deadline);
        emit DealFunded(dealId);
        return dealId;
    }

    function releaseFunds(uint256 dealId, uint256 amount) external onlyBuyer(dealId) inState(dealId, State.Funded) {
        Deal storage d = deals[dealId];
        uint256 remaining = d.amount - d.released;
        require(amount > 0 && amount <= remaining, "Invalid amount");

        d.released += amount;

        if (d.released == d.amount) {
            d.state = State.Completed;
            emit DealCompleted(dealId);
        } else {
            emit PartialRelease(dealId, amount);
        }

        (bool ok,) = d.seller.call{value: amount}("");
        require(ok, "Transfer failed");
    }

    function raiseDispute(uint256 dealId) external inState(dealId, State.Funded) {
        Deal storage d = deals[dealId];
        require(msg.sender == d.buyer || msg.sender == d.seller, "Not a party");
        d.state = State.Disputed;
        emit DisputeRaised(dealId, msg.sender);
    }

    function resolveDispute(uint256 dealId, uint256 sellerShare) external onlyArbiter inState(dealId, State.Disputed) {
        Deal storage d = deals[dealId];
        uint256 remaining = d.amount - d.released;
        require(sellerShare <= remaining, "Exceeds balance");

        uint256 buyerShare = remaining - sellerShare;
        d.released = d.amount;
        d.state = State.Resolved;

        emit DisputeResolved(dealId, sellerShare, buyerShare);

        if (sellerShare > 0) {
            (bool ok1,) = d.seller.call{value: sellerShare}("");
            require(ok1, "Seller transfer failed");
        }
        if (buyerShare > 0) {
            (bool ok2,) = d.buyer.call{value: buyerShare}("");
            require(ok2, "Buyer transfer failed");
        }
    }

    function claimRefund(uint256 dealId) external onlyBuyer(dealId) inState(dealId, State.Funded) {
        Deal storage d = deals[dealId];
        require(block.timestamp > d.deadline, "Deadline not passed");

        uint256 remaining = d.amount - d.released;
        d.released = d.amount;
        d.state = State.Refunded;

        emit DealRefunded(dealId);

        (bool ok,) = d.buyer.call{value: remaining}("");
        require(ok, "Transfer failed");
    }

    function getDeal(uint256 dealId) external view returns (
        address buyer,
        address seller,
        uint256 amount,
        uint256 released,
        uint256 deadline,
        State state
    ) {
        Deal storage d = deals[dealId];
        return (d.buyer, d.seller, d.amount, d.released, d.deadline, d.state);
    }
}