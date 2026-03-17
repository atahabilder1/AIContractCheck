// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Auction {
    // Core auction data
    address public immutable seller;
    address payable public beneficiary;
    string public item;

    uint256 public immutable reservePrice;
    uint256 public immutable minBidIncrement;

    uint64 public immutable startTime;
    uint64 public immutable endTime;

    address public highestBidder;
    uint256 public highestBid;

    bool public canceled;
    bool public settled;

    mapping(address => uint256) public pendingReturns;

    // Events
    event AuctionCreated(
        address indexed seller,
        address indexed beneficiary,
        string item,
        uint256 reservePrice,
        uint256 minBidIncrement,
        uint64 startTime,
        uint64 endTime
    );

    event BidPlaced(
        address indexed bidder,
        uint256 amount,
        bool reserveMet
    );

    event Withdrawn(address indexed bidder, uint256 amount);
    event Canceled();
    event Ended(address indexed winner, uint256 amount, bool reserveMet);
    event BeneficiaryUpdated(address indexed oldBeneficiary, address indexed newBeneficiary);

    // Modifiers
    modifier onlySeller() {
        require(msg.sender == seller, "Only seller");
        _;
    }

    modifier notSettled() {
        require(!settled, "Already settled");
        _;
    }

    constructor(
        string memory _item,
        uint256 _reservePrice,
        uint256 _minBidIncrement,
        uint64 _biddingDuration, // seconds
        address payable _beneficiary
    ) {
        require(_biddingDuration > 0, "Duration=0");
        require(_beneficiary != address(0), "Zero beneficiary");

        seller = msg.sender;
        beneficiary = _beneficiary;
        item = _item;

        reservePrice = _reservePrice;
        minBidIncrement = _minBidIncrement;

        uint64 start = uint64(block.timestamp);
        startTime = start;
        endTime = start + _biddingDuration;

        emit AuctionCreated(seller, beneficiary, item, reservePrice, minBidIncrement, startTime, endTime);
    }

    // Place a bid sending ETH
    function placeBid() external payable notSettled {
        require(!canceled, "Canceled");
        require(block.timestamp >= startTime, "Not started");
        require(block.timestamp < endTime, "Ended");
        uint256 minRequired = highestBid == 0 ? reservePrice : highestBid + minBidIncrement;
        require(msg.value >= minRequired, "Bid too low");

        // Put previous highest into withdrawable balance
        if (highestBidder != address(0)) {
            pendingReturns[highestBidder] += highestBid;
        }

        highestBidder = msg.sender;
        highestBid = msg.value;

        emit BidPlaced(msg.sender, msg.value, highestBid >= reservePrice);
    }

    // Withdraw outbid funds
    function withdraw() external returns (bool) {
        uint256 amount = pendingReturns[msg.sender];
        require(amount > 0, "Nothing to withdraw");

        pendingReturns[msg.sender] = 0;
        (bool ok, ) = payable(msg.sender).call{value: amount}("");
        require(ok, "Withdraw failed");

        emit Withdrawn(msg.sender, amount);
        return true;
    }

    // Cancel only before any valid bid and before end
    function cancel() external onlySeller notSettled {
        require(!canceled, "Already canceled");
        require(block.timestamp < endTime, "Already ended");
        require(highestBid == 0, "Active bid exists");

        canceled = true;
        settled = true; // Mark as settled; no further actions
        emit Canceled();
    }

    // Finalize the auction and handle funds
    function end() external notSettled {
        require(canceled || block.timestamp >= endTime, "Not ended");
        settled = true;

        if (canceled) {
            emit Ended(address(0), 0, false);
            return;
        }

        bool reserveMet = highestBid >= reservePrice;

        if (highestBidder == address(0)) {
            // No bids
            emit Ended(address(0), 0, false);
            return;
        }

        if (reserveMet) {
            uint256 amount = highestBid;
            // Effects already set (settled = true)
            (bool ok, ) = beneficiary.call{value: amount}("");
            require(ok, "Payout failed");
            emit Ended(highestBidder, amount, true);
        } else {
            // Reserve not met: allow highest bidder to withdraw
            pendingReturns[highestBidder] += highestBid;
            emit Ended(address(0), highestBid, false);
        }
    }

    // Update beneficiary; allowed anytime before settlement
    function setBeneficiary(address payable _beneficiary) external onlySeller notSettled {
        require(_beneficiary != address(0), "Zero beneficiary");
        address old = beneficiary;
        beneficiary = _beneficiary;
        emit BeneficiaryUpdated(old, _beneficiary);
    }

    // View helpers
    function isActive() public view returns (bool) {
        return !canceled && !settled && block.timestamp >= startTime && block.timestamp < endTime;
    }

    function timeLeft() external view returns (uint256) {
        if (block.timestamp >= endTime) return 0;
        return endTime - block.timestamp;
    }

    function minimumBid() external view returns (uint256) {
        if (settled || canceled) return 0;
        if (highestBid == 0) return reservePrice;
        return highestBid + minBidIncrement;
    }

    // Prevent accidental ETH sends
    receive() external payable {
        revert("Use placeBid");
    }

    fallback() external payable {
        revert("Unsupported");
    }
}