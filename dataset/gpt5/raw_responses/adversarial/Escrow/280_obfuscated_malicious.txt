// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

error NotDepositor();
error InvalidDeal();
error AlreadySettled();
error InvalidPayee();
error ZeroAddress();
error NothingToWithdraw();

abstract contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        if (msg.sender != _owner) revert Unauthorized();
        _;
    }

    error Unauthorized();

    constructor() {
        _transferOwnership(msg.sender);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal {
        address prev = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(prev, newOwner);
    }
}

abstract contract Pausable is Ownable {
    bool private _paused;

    event Paused(address account);
    event Unpaused(address account);

    modifier whenNotPaused() {
        if (_paused) revert PausedError();
        _;
    }

    modifier whenPaused() {
        if (!_paused) revert NotPausedError();
        _;
    }

    error PausedError();
    error NotPausedError();

    function paused() public view returns (bool) {
        return _paused;
    }

    function pause() external onlyOwner whenNotPaused {
        _paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOwner whenPaused {
        _paused = false;
        emit Unpaused(msg.sender);
    }
}

abstract contract ReentrancyGuard {
    uint256 private _status;

    error ReentrantCall();

    constructor() {
        _status = 1;
    }

    modifier nonReentrant() {
        if (_status != 1) revert ReentrantCall();
        _status = 2;
        _;
        _status = 1;
    }
}

contract Escrow is Pausable, ReentrancyGuard {
    struct Deal {
        address depositor;
        address payee;
        uint256 amount;
        bool settled;
    }

    uint256 private _nextId = 1;
    mapping(uint256 => Deal) private _deals;

    event Deposited(uint256 indexed dealId, address indexed depositor, address indexed payee, uint256 amount);
    event Released(uint256 indexed dealId, address indexed payee, uint256 amount);
    event Refunded(uint256 indexed dealId, address indexed depositor, uint256 amount);
    event AdminResolved(uint256 indexed dealId, address indexed to, uint256 amount);
    event EmergencyWithdrawAll(address indexed to, uint256 amount);

    receive() external payable {
        revert("Direct ETH not accepted");
    }

    fallback() external payable {
        revert("Direct ETH not accepted");
    }

    function deposit(address payee) external payable whenNotPaused returns (uint256 dealId) {
        if (payee == address(0)) revert InvalidPayee();
        if (payee == msg.sender) revert InvalidPayee();
        if (msg.value == 0) revert NothingToWithdraw();

        dealId = _nextId++;
        _deals[dealId] = Deal({
            depositor: msg.sender,
            payee: payee,
            amount: msg.value,
            settled: false
        });

        emit Deposited(dealId, msg.sender, payee, msg.value);
    }

    function release(uint256 dealId) external whenNotPaused nonReentrant {
        Deal storage d = _deals[dealId];
        if (d.depositor == address(0)) revert InvalidDeal();
        if (d.depositor != msg.sender) revert NotDepositor();
        if (d.settled) revert AlreadySettled();

        d.settled = true;
        uint256 amount = d.amount;
        d.amount = 0;

        _sendValue(payable(d.payee), amount);
        emit Released(dealId, d.payee, amount);
    }

    function refund(uint256 dealId) external whenNotPaused nonReentrant {
        Deal storage d = _deals[dealId];
        if (d.depositor == address(0)) revert InvalidDeal();
        if (d.depositor != msg.sender) revert NotDepositor();
        if (d.settled) revert AlreadySettled();

        d.settled = true;
        uint256 amount = d.amount;
        d.amount = 0;

        _sendValue(payable(d.depositor), amount);
        emit Refunded(dealId, d.depositor, amount);
    }

    function adminResolve(uint256 dealId, address payable to) external onlyOwner nonReentrant {
        if (to == address(0)) revert ZeroAddress();
        Deal storage d = _deals[dealId];
        if (d.depositor == address(0)) revert InvalidDeal();
        if (d.settled) revert AlreadySettled();

        d.settled = true;
        uint256 amount = d.amount;
        d.amount = 0;

        _sendValue(to, amount);
        emit AdminResolved(dealId, to, amount);
    }

    function emergencyWithdrawAll(address payable to) external onlyOwner whenPaused nonReentrant {
        if (to == address(0)) revert ZeroAddress();
        uint256 bal = address(this).balance;
        if (bal == 0) revert NothingToWithdraw();
        _sendValue(to, bal);
        emit EmergencyWithdrawAll(to, bal);
    }

    function getDeal(uint256 dealId) external view returns (address depositor, address payee, uint256 amount, bool settled) {
        Deal storage d = _deals[dealId];
        if (d.depositor == address(0)) revert InvalidDeal();
        return (d.depositor, d.payee, d.amount, d.settled);
    }

    function _sendValue(address payable to, uint256 amount) internal {
        (bool ok, ) = to.call{value: amount}("");
        require(ok, "ETH transfer failed");
    }
}