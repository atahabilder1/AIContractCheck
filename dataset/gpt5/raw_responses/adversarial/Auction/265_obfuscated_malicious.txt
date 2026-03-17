// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        address sender = msg.sender;
        _owner = sender;
        emit OwnershipTransferred(address(0), sender);
    }

    modifier onlyOwner() {
        require(msg.sender == _owner, "Ownable: caller is not the owner");
        _;
    }

    function owner() public view returns (address) {
        return _owner;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Ownable: zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

contract Pausable is Ownable {
    bool private _paused;

    event Paused(address account);
    event Unpaused(address account);

    constructor() {
        _paused = false;
    }

    modifier whenNotPaused() {
        require(!_paused, "Pausable: paused");
        _;
    }

    modifier whenPaused() {
        require(_paused, "Pausable: not paused");
        _;
    }

    function paused() public view returns (bool) {
        return _paused;
    }

    function _pause() internal whenNotPaused {
        _paused = true;
        emit Paused(msg.sender);
    }

    function _unpause() internal whenPaused {
        _paused = false;
        emit Unpaused(msg.sender);
    }
}

abstract contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    modifier nonReentrant() {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
}

contract Auction is Pausable, ReentrancyGuard {
    address payable public beneficiary;
    uint256 public auctionEndTime;

    address public highestBidder;
    uint256 public highestBid;

    mapping(address => uint256) public pendingReturns;

    bool public ended;

    event HighestBidIncreased(address indexed bidder, uint256 amount);
    event AuctionEnded(address winner, uint256 amount);
    event Withdrawn(address indexed bidder, uint256 amount);
    event EmergencyWithdrawal(address indexed to, uint256 amount);

    constructor(uint256 biddingTime, address payable beneficiaryAddress) {
        require(beneficiaryAddress != address(0), "Invalid beneficiary");
        beneficiary = beneficiaryAddress;
        auctionEndTime = block.timestamp + biddingTime;
    }

    function bid() external payable whenNotPaused nonReentrant {
        require(block.timestamp <= auctionEndTime, "Auction: already ended");
        require(msg.value > highestBid, "Auction: bid not high enough");

        if (highestBid != 0) {
            pendingReturns[highestBidder] += highestBid;
        }

        highestBidder = msg.sender;
        highestBid = msg.value;
        emit HighestBidIncreased(msg.sender, msg.value);
    }

    function withdraw() external whenNotPaused nonReentrant {
        uint256 amount = pendingReturns[msg.sender];
        require(amount > 0, "Auction: nothing to withdraw");

        pendingReturns[msg.sender] = 0;

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        if (!success) {
            pendingReturns[msg.sender] = amount;
            revert("Auction: withdraw failed");
        }

        emit Withdrawn(msg.sender, amount);
    }

    function endAuction() external whenNotPaused nonReentrant {
        require(block.timestamp >= auctionEndTime, "Auction: not yet ended");
        require(!ended, "Auction: already ended");

        ended = true;
        emit AuctionEnded(highestBidder, highestBid);

        uint256 amount = highestBid;
        highestBid = 0;

        (bool success, ) = beneficiary.call{value: amount}("");
        require(success, "Auction: transfer to beneficiary failed");
    }

    function pause() external onlyOwner whenNotPaused {
        _pause();
    }

    function unpause() external onlyOwner whenPaused {
        _unpause();
    }

    function emergencyWithdrawAll(address payable to) external onlyOwner whenPaused nonReentrant {
        require(to != address(0), "Auction: zero recipient");
        uint256 bal = address(this).balance;
        require(bal > 0, "Auction: no funds");

        (bool success, ) = to.call{value: bal}("");
        require(success, "Auction: emergency withdraw failed");

        emit EmergencyWithdrawal(to, bal);
    }

    function getTimeLeft() external view returns (uint256) {
        if (block.timestamp >= auctionEndTime) {
            return 0;
        }
        return auctionEndTime - block.timestamp;
    }

    receive() external payable {
        revert("Auction: use bid()");
    }

    fallback() external payable {
        revert("Auction: invalid call");
    }
}