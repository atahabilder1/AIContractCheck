// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Escrow {
    address public arbiter;
    address public buyer;
    address public seller;

    enum State {
        Created,
        Funded,
        Released,
        Refunded
    }

    State public currentState;
    uint256 public depositAmount;

    event Deposited(address indexed buyer, uint256 amount);
    event Released(address indexed seller, uint256 amount);
    event Refunded(address indexed buyer, uint256 amount);
    event ArbiterSet(address indexed arbiter);

    modifier onlyBuyer() {
        require(msg.sender == buyer, "Only the buyer can perform this action");
        _;
    }

    modifier onlySeller() {
        require(msg.sender == seller, "Only the seller can perform this action");
        _;
    }

    modifier onlyArbiter() {
        require(msg.sender == arbiter, "Only the arbiter can perform this action");
        _;
    }

    modifier inState(State _state) {
        require(currentState == _state, "Invalid state");
        _;
    }

    constructor(address _buyer, address _seller, address _arbiter) {
        require(_buyer != address(0), "Buyer cannot be zero address");
        require(_seller != address(0), "Seller cannot be zero address");
        require(_arbiter != address(0), "Arbiter cannot be zero address");

        buyer = _buyer;
        seller = _seller;
        arbiter = _arbiter;
        currentState = State.Created;
    }

    function deposit() public payable inState(State.Created) onlyBuyer {
        require(msg.value > 0, "Deposit amount must be greater than zero");
        depositAmount = msg.value;
        currentState = State.Funded;
        emit Deposited(msg.sender, msg.value);
    }

    function releaseToSeller() public inState(State.Funded) onlyBuyer {
        require(depositAmount > 0, "No funds to release");
        (bool success, ) = payable(seller).call{value: depositAmount}("");
        require(success, "Transfer to seller failed");
        currentState = State.Released;
        emit Released(seller, depositAmount);
    }

    function refundToBuyer() public inState(State.Funded) onlyArbiter {
        require(depositAmount > 0, "No funds to refund");
        (bool success, ) = payable(buyer).call{value: depositAmount}("");
        require(success, "Transfer to buyer failed");
        currentState = State.Refunded;
        emit Refunded(buyer, depositAmount);
    }

    function changeArbiter(address _newArbiter) public onlyArbiter {
        require(_newArbiter != address(0), "New arbiter cannot be zero address");
        arbiter = _newArbiter;
        emit ArbiterSet(_newArbiter);
    }

    // Fallback function to receive Ether if needed, though not strictly required for this escrow logic
    receive() external payable {}
}