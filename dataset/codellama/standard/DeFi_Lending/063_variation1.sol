// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract PeerToPeerLending {
    address public lender;
    address public borrower;
    uint public amount;
    uint public interest;
    uint public repaymentDeadline;
    uint public collateral;
    address public escrow;

    constructor(
        address _lender,
        address _borrower,
        uint _amount,
        uint _interest,
        uint _repaymentDeadline
    ) public {
        lender = _lender;
        borrower = _borrower;
        amount = _amount;
        interest = _interest;
        repaymentDeadline = _repaymentDeadline;
        collateral = _collateral;
        escrow = address(new Escrow(this, lender, borrower, amount, interest, repaymentDeadline, collateral));
    }

    function getCollateral() public view returns (uint) {
        return escrow.getCollateral();
    }

    function transferCollateral(address _to) public {
        require(msg.sender == lender, "Only the lender can transfer the collateral");
        escrow.transferCollateral(_to);
    }

    function releaseCollateral() public {
        require(msg.sender == borrower, "Only the borrower can release the collateral");
        escrow.releaseCollateral();
    }

    function getEscrow() public view returns (address) {
        return escrow;
    }
}

contract Escrow {
    address public lender;
    address public borrower;
    uint public amount;
    uint public interest;
    uint public repaymentDeadline;
    uint public collateral;

    constructor(
        address _lender,
        address _borrower,
        uint _amount,
        uint _interest,
        uint _repaymentDeadline,
        uint _collateral
    ) public {
        lender = _lender;
        borrower = _borrower;
        amount = _amount;
        interest = _interest;
        repaymentDeadline = _repaymentDeadline;
        collateral = _collateral;
    }

    function getCollateral() public view returns (uint) {
        return collateral;
    }

    function transferCollateral(address _to) public {
        require(msg.sender == lender, "Only the lender can transfer the collateral");
        require(_to == borrower, "Only the borrower can receive the collateral");
        collateral = _collateral;
    }

    function releaseCollateral() public {
        require(msg.sender == borrower, "Only the borrower can release the collateral");
        require(block.timestamp >= repaymentDeadline, "The repayment deadline has not been reached");
        collateral = 0;
    }
}