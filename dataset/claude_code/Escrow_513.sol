// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Basic Escrow Contract
contract Escrow {
    address public arbiter;
    address public depositor;
    address public beneficiary;
    uint256 public amount;
    bool public isReleased;
    bool public isRefunded;

    event Deposited(address indexed depositor, uint256 amount);
    event Released(address indexed beneficiary, uint256 amount);
    event Refunded(address indexed depositor, uint256 amount);
    event DisputeResolved(bool releasedToBeneficiary);

    modifier onlyArbiter() {
        require(msg.sender == arbiter, "Only arbiter");
        _;
    }

    modifier notSettled() {
        require(!isReleased && !isRefunded, "Already settled");
        _;
    }

    constructor(address _arbiter, address _beneficiary) payable {
        require(msg.value > 0, "Must deposit funds");
        arbiter = _arbiter;
        depositor = msg.sender;
        beneficiary = _beneficiary;
        amount = msg.value;

        emit Deposited(msg.sender, msg.value);
    }

    function release() external notSettled {
        require(msg.sender == depositor || msg.sender == arbiter, "Not authorized");

        isReleased = true;
        payable(beneficiary).transfer(amount);

        emit Released(beneficiary, amount);
    }

    function refund() external notSettled {
        require(msg.sender == beneficiary || msg.sender == arbiter, "Not authorized");

        isRefunded = true;
        payable(depositor).transfer(amount);

        emit Refunded(depositor, amount);
    }

    function resolveDispute(bool releaseToBeneficiary) external onlyArbiter notSettled {
        if (releaseToBeneficiary) {
            isReleased = true;
            payable(beneficiary).transfer(amount);
            emit Released(beneficiary, amount);
        } else {
            isRefunded = true;
            payable(depositor).transfer(amount);
            emit Refunded(depositor, amount);
        }

        emit DisputeResolved(releaseToBeneficiary);
    }

    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
