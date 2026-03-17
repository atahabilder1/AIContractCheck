// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Escrow {
    address payable public immutable buyer;
    address payable public immutable seller;
    address public immutable arbiter;
    uint256 public immutable price;

    bool public funded;
    bool public released;
    bool public refunded;
    uint256 public depositedAt;

    // Simple non-reentrancy guard
    uint256 private _status;
    uint256 private constant _ENTERED = 1;
    uint256 private constant _NOT_ENTERED = 2;

    event Deposited(address indexed buyer, uint256 amount);
    event Released(address indexed seller, uint256 amount, address indexed by);
    event Refunded(address indexed buyer, uint256 amount, address indexed by);

    modifier nonReentrant() {
        require(_status != _ENTERED, "Reentrancy");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

    modifier onlyBuyer() {
        require(msg.sender == buyer, "Not buyer");
        _;
    }

    modifier onlyBuyerOrArbiter() {
        require(msg.sender == buyer || msg.sender == arbiter, "Not authorized");
        _;
    }

    constructor(address payable _buyer, address payable _seller, address _arbiter, uint256 _price) {
        require(_buyer != address(0) && _seller != address(0), "Zero address");
        require(_price > 0, "Price=0");
        buyer = _buyer;
        seller = _seller;
        arbiter = _arbiter; // can be zero address if no arbiter is used
        price = _price;
        _status = _NOT_ENTERED;
    }

    function deposit() external payable onlyBuyer {
        require(!funded, "Already funded");
        require(!released && !refunded, "Escrow closed");
        require(msg.value == price, "Incorrect amount");
        funded = true;
        depositedAt = block.timestamp;
        emit Deposited(msg.sender, msg.value);
    }

    function release() external onlyBuyerOrArbiter nonReentrant {
        require(funded, "Not funded");
        require(!released && !refunded, "Escrow closed");
        released = true;
        funded = false;

        (bool ok, ) = seller.call{value: price}("");
        require(ok, "Transfer failed");
        emit Released(seller, price, msg.sender);
    }

    function refund() external onlyBuyerOrArbiter nonReentrant {
        require(funded, "Not funded");
        require(!released && !refunded, "Escrow closed");
        refunded = true;
        funded = false;

        (bool ok, ) = buyer.call{value: price}("");
        require(ok, "Transfer failed");
        emit Refunded(buyer, price, msg.sender);
    }

    function escrowBalance() external view returns (uint256) {
        return address(this).balance;
    }

    receive() external payable {
        revert("Use deposit()");
    }

    fallback() external payable {
        revert("Invalid call");
    }
}