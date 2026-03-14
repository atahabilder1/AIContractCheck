// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CrowdfundingICO {
    address payable public owner;
    address public admin;

    uint256 public startTime;
    uint256 public endTime;
    uint256 public targetAmount;
    uint256 public raisedAmount;
    uint256 public weiRaised;

    bool public fundraisingActive = false;
    bool public paused = false;

    struct Investor {
        uint256 amount;
        bool invested;
    }

    mapping(address => Investor) public investors;
    address[] public contributors;

    event Contribution(address indexed investor, uint256 amount);
    event Withdrawal(address indexed recipient, uint256 amount);
    event EmergencyWithdrawal(address indexed recipient, uint256 amount);
    event Pause();
    event Unpause();
    event FundraisingActivated();

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can perform this action.");
        _;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only the admin can perform this action.");
        _;
    }

    modifier whenFundraisingActive() {
        require(fundraisingActive, "Fundraising is not active.");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "Contract is paused.");
        _;
    }

    modifier whenFundraisingNotActive() {
        require(!fundraisingActive, "Fundraising is already active.");
        _;
    }

    constructor(
        uint256 _startTime,
        uint256 _endTime,
        uint256 _targetAmount // in wei
    ) {
        owner = payable(msg.sender);
        admin = msg.sender; // Initially, the owner is also the admin
        startTime = _startTime;
        endTime = _endTime;
        targetAmount = _targetAmount;
    }

    function setAdmin(address _admin) public onlyOwner {
        admin = _admin;
    }

    function activateFundraising() public onlyOwner whenFundraisingNotActive {
        require(block.timestamp >= startTime, "Fundraising has not started yet.");
        require(block.timestamp < endTime, "Fundraising period has already ended.");
        fundraisingActive = true;
        emit FundraisingActivated();
    }

    function contribute() public payable whenFundraisingActive whenNotPaused {
        require(block.timestamp >= startTime && block.timestamp < endTime, "Contribution is only allowed during the active fundraising period.");
        require(msg.value > 0, "Contribution amount must be greater than zero.");

        if (!investors[msg.sender].invested) {
            investors[msg.sender].invested = true;
            contributors.push(msg.sender);
        }
        investors[msg.sender].amount += msg.value;
        weiRaised += msg.value;

        emit Contribution(msg.sender, msg.value);
    }

    function withdrawFunds() public onlyOwner {
        require(block.timestamp >= endTime, "Funds can only be withdrawn after the fundraising period ends.");
        require(weiRaised >= targetAmount, "Target amount not reached, funds will be returned to investors.");

        uint256 amountToWithdraw = address(this).balance;
        require(amountToWithdraw > 0, "No funds to withdraw.");

        (bool success, ) = owner.call{value: amountToWithdraw}("");
        require(success, "Withdrawal failed.");

        emit Withdrawal(owner, amountToWithdraw);
    }

    function refundInvestors() public {
        require(block.timestamp >= endTime, "Refunds can only be initiated after the fundraising period ends.");
        require(weiRaised < targetAmount, "Target amount was reached, no refunds needed.");

        uint256 investorAmount = investors[msg.sender].amount;
        require(investorAmount > 0, "You have not invested or have already received a refund.");

        investors[msg.sender].amount = 0;
        investors[msg.sender].invested = false;

        (bool success, ) = payable(msg.sender).call{value: investorAmount}("");
        require(success, "Refund failed.");

        emit Withdrawal(msg.sender, investorAmount);
    }

    // Emergency functions
    function pause() public onlyAdmin {
        require(!paused, "Contract is already paused.");
        paused = true;
        emit Pause();
    }

    function unpause() public onlyAdmin {
        require(paused, "Contract is not paused.");
        paused = false;
        emit Unpause();
    }

    function emergencyWithdrawAll() public onlyAdmin whenFundraisingActive {
        require(paused, "Emergency withdrawal only allowed when paused.");
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw.");

        (bool success, ) = payable(admin).call{value: balance}("");
        require(success, "Emergency withdrawal failed.");

        emit EmergencyWithdrawal(admin, balance);
    }

    // Fallback function to receive Ether
    receive() external payable {
        contribute();
    }

    // Function to check contract balance
    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }

    // Function to check if fundraising is over
    function isFundraisingOver() public view returns (bool) {
        return block.timestamp >= endTime;
    }
}