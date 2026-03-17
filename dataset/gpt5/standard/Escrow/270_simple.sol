// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Escrow {
    address payable public immutable buyer;
    address payable public immutable seller;

    uint256 public deposited;
    bool public isFunded;
    bool public isReleased;
    bool public isRefunded;

    bool private locked;

    event Deposited(address indexed buyer, uint256 amount);
    event Released(address indexed seller, uint256 amount);
    event Refunded(address indexed buyer, uint256 amount);

    error NotBuyer();
    error InvalidAddress();
    error InvalidAmount();
    error AlreadyFunded();
    error NotFunded();
    error AlreadyCompleted();
    error ReentrancyGuard();

    modifier onlyBuyer() {
        if (msg.sender != buyer) revert NotBuyer();
        _;
    }

    modifier nonReentrant() {
        if (locked) revert ReentrancyGuard();
        locked = true;
        _;
        locked = false;
    }

    constructor(address payable _buyer, address payable _seller) {
        if (_buyer == address(0) || _seller == address(0)) revert InvalidAddress();
        buyer = _buyer;
        seller = _seller;
    }

    receive() external payable {
        revert("Use deposit()");
    }

    function deposit() external payable onlyBuyer {
        if (isFunded || isReleased || isRefunded) revert AlreadyCompleted();
        if (msg.value == 0) revert InvalidAmount();
        if (isFunded) revert AlreadyFunded();

        deposited = msg.value;
        isFunded = true;

        emit Deposited(msg.sender, msg.value);
    }

    function confirmDelivery() external onlyBuyer nonReentrant {
        if (!isFunded) revert NotFunded();
        if (isReleased || isRefunded) revert AlreadyCompleted();

        uint256 amount = deposited;

        // Effects
        isReleased = true;
        isFunded = false;
        deposited = 0;

        // Interaction
        (bool ok, ) = seller.call{value: amount}("");
        require(ok, "Transfer failed");

        emit Released(seller, amount);
    }

    function refund() external onlyBuyer nonReentrant {
        if (!isFunded) revert NotFunded();
        if (isReleased || isRefunded) revert AlreadyCompleted();

        uint256 amount = deposited;

        // Effects
        isRefunded = true;
        isFunded = false;
        deposited = 0;

        // Interaction
        (bool ok, ) = buyer.call{value: amount}("");
        require(ok, "Refund failed");

        emit Refunded(buyer, amount);
    }

    function contractBalance() external view returns (uint256) {
        return address(this).balance;
    }
}