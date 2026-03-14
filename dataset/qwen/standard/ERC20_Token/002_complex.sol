// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/governance/utils/Votes.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract GovernanceToken is ERC20, ERC20Votes, ERC20Permit, ERC20Snapshot, ERC20Burnable, Pausable, Ownable {
    using SafeMath for uint256;

    struct VestingSchedule {
        uint256 totalAmount;
        uint256 releasedAmount;
        uint256 start;
        uint256 duration;
        uint256 cliff;
    }

    mapping(address => VestingSchedule) public vestingSchedules;

    event VestingScheduleAdded(address indexed beneficiary, uint256 totalAmount, uint256 start, uint256 duration, uint256 cliff);
    event VestingScheduleReleased(address indexed beneficiary, uint256 releasedAmount);

    constructor(string memory name, string memory symbol) ERC20(name, symbol) ERC20Permit(name) {}

    function snapshot() external onlyOwner returns (uint256) {
        return _snapshot();
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal override(ERC20, ERC20Votes, ERC20Snapshot) {
        super._beforeTokenTransfer(from, to, amount);
    }

    function _afterTokenTransfer(address from, address to, uint256 amount) internal override(ERC20, ERC20Votes) {
        super._afterTokenTransfer(from, to, amount);
    }

    function _mint(address to, uint256 amount) internal override(ERC20, ERC20Votes) {
        super._mint(to, amount);
    }

    function _burn(address account, uint256 amount) internal override(ERC20, ERC20Votes) {
        super._burn(account, amount);
    }

    function addVestingSchedule(address beneficiary, uint256 totalAmount, uint256 start, uint256 duration, uint256 cliff) external onlyOwner {
        require(vestingSchedules[beneficiary].totalAmount == 0, "Vesting schedule already exists");
        require(totalAmount > 0, "Total amount must be greater than 0");
        require(duration > 0, "Duration must be greater than 0");
        require(cliff <= duration, "Cliff must be less than or equal to duration");

        vestingSchedules[beneficiary] = VestingSchedule({
            totalAmount: totalAmount,
            releasedAmount: 0,
            start: start,
            duration: duration,
            cliff: cliff
        });

        emit VestingScheduleAdded(beneficiary, totalAmount, start, duration, cliff);
    }

    function releaseVesting(address beneficiary) external {
        VestingSchedule storage schedule = vestingSchedules[beneficiary];
        require(schedule.totalAmount > 0, "No vesting schedule for this address");

        uint256 totalVesting = getTotalVesting(beneficiary);
        uint256 releasable = totalVesting.sub(schedule.releasedAmount);

        require(releasable > 0, "No tokens are currently releasable");

        _transfer(address(this), beneficiary, releasable);
        schedule.releasedAmount = schedule.releasedAmount.add(releasable);

        emit VestingScheduleReleased(beneficiary, releasable);
    }

    function getTotalVesting(address beneficiary) public view returns (uint256) {
        VestingSchedule storage schedule = vestingSchedules[beneficiary];
        uint256 currentTime = block.timestamp;

        if (currentTime < schedule.start.add(schedule.cliff)) {
            return 0;
        }

        uint256 elapsedTime = currentTime.sub(schedule.start);
        uint256 vestingPeriods = elapsedTime.div(schedule.duration);
        uint256 totalVesting = schedule.totalAmount.mul(vestingPeriods).div(schedule.duration);

        return totalVesting;
    }

    function releaseable(address beneficiary) external view returns (uint256) {
        VestingSchedule storage schedule = vestingSchedules[beneficiary];
        return getTotalVesting(beneficiary).sub(schedule.releasedAmount);
    }
}