pragma solidity ^0.8.0;

contract Escrow {
    address private _arbiter;
    address private _seller;
    address private _buyer;
    uint private _amount;
    uint private _deadline;
    bool private _disputeResolved;
    bool private _deadlineEnforced;
    uint private _partialRelease;

    constructor(address arbiter, address seller, address buyer, uint amount, uint deadline) public {
        _arbiter = arbiter;
        _seller = seller;
        _buyer = buyer;
        _amount = amount;
        _deadline = deadline;
        _disputeResolved = false;
        _deadlineEnforced = false;
        _partialRelease = 0;
    }

    function release() public {
        require(msg.sender == _arbiter, "Only the arbiter can release the funds");
        require(_disputeResolved == false, "Dispute has been resolved");
        require(_deadlineEnforced == false, "Deadline has been enforced");
        _seller.transfer(_amount);
        _disputeResolved = true;
    }

    function dispute() public {
        require(msg.sender == _buyer, "Only the buyer can dispute the transaction");
        require(_disputeResolved == false, "Dispute has been resolved");
        require(_deadlineEnforced == false, "Deadline has been enforced");
        _arbiter.transfer(_amount);
        _disputeResolved = true;
    }

    function deadline() public {
        require(_deadlineEnforced == false, "Deadline has been enforced");
        require(block.timestamp > _deadline, "Deadline has not been reached");
        _partialRelease = _amount / 2;
        _seller.transfer(_partialRelease);
        _buyer.transfer(_partialRelease);
        _deadlineEnforced = true;
    }

    function getPartialRelease() public view returns (uint) {
        return _partialRelease;
    }

    function getDisputeResolved() public view returns (bool) {
        return _disputeResolved;
    }

    function getDeadlineEnforced() public view returns (bool) {
        return _deadlineEnforced;
    }
}