// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Escrow {
    address public owner;
    address public admin;
    bool public paused = false;

    struct Deposit {
        address depositor;
        address beneficiary;
        uint256 amount;
        bool released;
        bool cancelled;
    }

    mapping(uint256 => Deposit) public deposits;
    uint256 public nextDepositId;

    event DepositCreated(uint256 indexed depositId, address indexed depositor, address indexed beneficiary, uint256 amount);
    event FundsReleased(uint256 indexed depositId);
    event FundsCancelled(uint256 indexed depositId);
    event OwnerTransferred(address indexed newOwner);
    event AdminTransferred(address indexed newAdmin);
    event Paused();
    event Unpaused();
    event EmergencyWithdraw(address indexed admin, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Escrow: Caller is not the owner");
        _;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Escrow: Caller is not the admin");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "Escrow: Contract is paused");
        _;
    }

    modifier whenPaused() {
        require(paused, "Escrow: Contract is not paused");
        _;
    }

    constructor(address _admin) {
        owner = msg.sender;
        admin = _admin;
        nextDepositId = 1;
    }

    // Owner functions
    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "Escrow: New owner cannot be the zero address");
        owner = newOwner;
        emit OwnerTransferred(newOwner);
    }

    function transferAdmin(address newAdmin) public onlyOwner {
        require(newAdmin != address(0), "Escrow: New admin cannot be the zero address");
        admin = newAdmin;
        emit AdminTransferred(newAdmin);
    }

    // Admin functions
    function pause() public onlyAdmin whenNotPaused {
        paused = true;
        emit Paused();
    }

    function unpause() public onlyAdmin whenPaused {
        paused = false;
        emit Unpaused();
    }

    function emergencyWithdrawAll() public onlyAdmin {
        uint256 balance = address(this).balance;
        require(balance > 0, "Escrow: No funds to withdraw");
        (bool success, ) = payable(admin).call{value: balance}("");
        require(success, "Escrow: Emergency withdrawal failed");
        emit EmergencyWithdraw(admin, balance);
    }

    // Escrow functions
    function createDeposit(address beneficiary, uint256 amount) public payable whenNotPaused {
        require(beneficiary != address(0), "Escrow: Beneficiary cannot be the zero address");
        require(msg.value == amount, "Escrow: Sent amount does not match deposit amount");
        require(amount > 0, "Escrow: Deposit amount must be greater than zero");

        uint256 depositId = nextDepositId++;
        deposits[depositId] = Deposit({
            depositor: msg.sender,
            beneficiary: beneficiary,
            amount: amount,
            released: false,
            cancelled: false
        });

        emit DepositCreated(depositId, msg.sender, beneficiary, amount);
    }

    function releaseFunds(uint256 depositId) public whenNotPaused {
        Deposit storage deposit = deposits[depositId];
        require(deposit.depositor != address(0), "Escrow: Deposit does not exist");
        require(msg.sender == deposit.depositor, "Escrow: Caller is not the depositor");
        require(!deposit.released, "Escrow: Funds already released");
        require(!deposit.cancelled, "Escrow: Deposit was cancelled");

        deposit.released = true;
        (bool success, ) = payable(deposit.beneficiary).call{value: deposit.amount}("");
        require(success, "Escrow: Fund release to beneficiary failed");

        emit FundsReleased(depositId);
    }

    function cancelDeposit(uint256 depositId) public whenNotPaused {
        Deposit storage deposit = deposits[depositId];
        require(deposit.depositor != address(0), "Escrow: Deposit does not exist");
        require(msg.sender == deposit.depositor, "Escrow: Caller is not the depositor");
        require(!deposit.released, "Escrow: Funds already released");
        require(!deposit.cancelled, "Escrow: Deposit was already cancelled");

        deposit.cancelled = true;
        (bool success, ) = payable(deposit.depositor).call{value: deposit.amount}("");
        require(success, "Escrow: Fund refund to depositor failed");

        emit FundsCancelled(depositId);
    }

    // Fallback function to receive Ether
    receive() external payable {}
    fallback() external payable {}
}