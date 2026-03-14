// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract HackathonCrowdfund {
    address payable public owner;
    uint256 public fundingGoal;
    uint256 public deadline;
    uint256 public raisedAmount;
    mapping(address => uint256) public contributors;
    bool public fundingSuccessful = false;
    bool public projectEnded = false;

    event Contribution(address indexed contributor, uint256 amount);
    event Withdrawal(address indexed recipient, uint256 amount);
    event Refund(address indexed contributor, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can call this function.");
        _;
    }

    modifier inProgress() {
        require(block.timestamp < deadline, "Crowdfunding has ended.");
        _;
    }

    modifier ended() {
        require(projectEnded, "Crowdfunding is still in progress.");
        _;
    }

    constructor(uint256 _fundingGoal, uint256 _durationInDays) {
        owner = payable(msg.sender);
        fundingGoal = _fundingGoal;
        deadline = block.timestamp + (_durationInDays * 1 days);
    }

    function contribute() external payable inProgress {
        require(msg.value > 0, "Contribution must be greater than 0.");
        contributors[msg.sender] += msg.value;
        raisedAmount += msg.value;
        emit Contribution(msg.sender, msg.value);
    }

    function endCrowdfund() public onlyOwner {
        require(block.timestamp >= deadline, "Crowdfunding has not ended yet.");
        projectEnded = true;
        if (raisedAmount >= fundingGoal) {
            fundingSuccessful = true;
        }
    }

    function withdrawFunds() public onlyOwner ended {
        require(fundingSuccessful, "Funding was not successful.");
        uint256 amountToWithdraw = address(this).balance;
        require(amountToWithdraw > 0, "No funds to withdraw.");
        (bool success, ) = owner.call{value: amountToWithdraw}("");
        require(success, "Withdrawal failed.");
        emit Withdrawal(owner, amountToWithdraw);
    }

    function refund() external ended {
        require(!fundingSuccessful, "Funding was successful, no refunds.");
        uint256 amountToRefund = contributors[msg.sender];
        require(amountToRefund > 0, "You have not contributed or already refunded.");

        contributors[msg.sender] = 0;
        (bool success, ) = payable(msg.sender).call{value: amountToRefund}("");
        require(success, "Refund failed.");
        emit Refund(msg.sender, amountToRefund);
    }

    // Fallback function to receive Ether directly (optional but good for simplicity)
    receive() external payable inProgress {
        contribute();
    }

    fallback() external payable inProgress {
        contribute();
    }
}