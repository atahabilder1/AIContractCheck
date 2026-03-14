// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Timelock {
    address public owner;
    mapping(address => uint256) public releaseTimes;
    mapping(uint256 => address) public beneficiaries;
    mapping(uint256 => uint256) public amounts;
    uint256 public beneficiaryCount;

    event Deposit(address indexed beneficiary, uint256 amount, uint256 releaseTime);
    event Withdrawal(address indexed beneficiary, uint256 amount);

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Timelock: Caller is not the owner");
        _;
    }

    function schedule(address beneficiary, uint256 amount, uint256 releaseTime) public onlyOwner {
        require(beneficiary != address(0), "Timelock: Beneficiary cannot be the zero address");
        require(releaseTime > block.timestamp, "Timelock: Release time must be in the future");

        uint256 currentBeneficiaryIndex = beneficiaryCount;
        beneficiaries[currentBeneficiaryIndex] = beneficiary;
        amounts[currentBeneficiaryIndex] = amount;
        releaseTimes[beneficiary] = releaseTime; // Assuming one release time per beneficiary for simplicity. If multiple, a different mapping structure would be needed.
        beneficiaryCount++;

        emit Deposit(beneficiary, amount, releaseTime);
    }

    function withdraw() public {
        uint256 amountToWithdraw = 0;
        uint256 beneficiaryIndex = 0;
        address payable beneficiaryAddress = payable(msg.sender);

        // Find the scheduled amount for the current caller
        for (uint256 i = 0; i < beneficiaryCount; i++) {
            if (beneficiaries[i] == beneficiaryAddress) {
                if (block.timestamp >= releaseTimes[beneficiaryAddress]) {
                    amountToWithdraw = amounts[i];
                    beneficiaryIndex = i;
                    break; // Found the beneficiary, exit loop
                } else {
                    revert("Timelock: Release time not yet reached");
                }
            }
        }

        require(amountToWithdraw > 0, "Timelock: No scheduled amount found for withdrawal or release time not met");

        // Reset the scheduled amount to prevent double withdrawal
        amounts[beneficiaryIndex] = 0;
        releaseTimes[beneficiaryAddress] = 0; // Clear release time for this beneficiary

        (bool success, ) = beneficiaryAddress.call{value: amountToWithdraw}("");
        require(success, "Timelock: Withdrawal failed");

        emit Withdrawal(beneficiaryAddress, amountToWithdraw);
    }

    function cancel(uint256 beneficiaryIndex) public onlyOwner {
        require(beneficiaryIndex < beneficiaryCount, "Timelock: Invalid beneficiary index");
        address beneficiary = beneficiaries[beneficiaryIndex];
        require(beneficiary != address(0), "Timelock: Beneficiary already cancelled or does not exist");

        uint256 amount = amounts[beneficiaryIndex];
        // Clear the scheduled deposit
        amounts[beneficiaryIndex] = 0;
        releaseTimes[beneficiary] = 0; // Clear release time for this beneficiary
        beneficiaries[beneficiaryIndex] = address(0); // Mark as cancelled

        // Note: This implementation does not handle reclaiming funds from the contract
        // directly via cancel. The funds would need to be sent back to the owner or
        // a new beneficiary. For simplicity, this function only cancels the schedule.
        // A more robust implementation might return funds to the owner.

        // To return funds to owner, you would need to:
        // 1. Transfer the `amount` back to `owner`.
        // 2. Ensure the contract has sufficient balance.
        // This would require additional logic and potentially changing the owner's role.
    }

    function getScheduledAmount(address beneficiary) public view returns (uint256) {
        for (uint256 i = 0; i < beneficiaryCount; i++) {
            if (beneficiaries[i] == beneficiary) {
                return amounts[i];
            }
        }
        return 0;
    }

    function getReleaseTime(address beneficiary) public view returns (uint256) {
        return releaseTimes[beneficiary];
    }

    receive() external payable {} // Allow contract to receive Ether
}