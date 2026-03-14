// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

contract GovernanceToken is ERC20, ERC20Burnable, ERC20Permit, ERC20Votes, Ownable, ReentrancyGuard, Pausable {

    // ─── Snapshots ───────────────────────────────────────────────

    struct Snapshot {
        uint256 id;
        uint256 blockNumber;
        uint256 timestamp;
    }

    uint256 private _currentSnapshotId;
    Snapshot[] private _snapshots;

    mapping(address => mapping(uint256 => uint256)) private _balanceSnapshots;
    mapping(address => mapping(uint256 => bool)) private _balanceSnapshotted;
    mapping(uint256 => uint256) private _totalSupplySnapshots;

    event SnapshotCreated(uint256 indexed id, uint256 blockNumber);

    // ─── Vesting ─────────────────────────────────────────────────

    struct VestingSchedule {
        uint256 totalAmount;
        uint256 releasedAmount;
        uint256 startTime;
        uint256 cliffEnd;
        uint256 vestingEnd;
        bool revocable;
        bool revoked;
    }

    mapping(address => VestingSchedule[]) private _vestingSchedules;
    uint256 public totalVestedAmount;

    event VestingScheduleCreated(
        address indexed beneficiary,
        uint256 index,
        uint256 totalAmount,
        uint256 startTime,
        uint256 cliffEnd,
        uint256 vestingEnd,
        bool revocable
    );
    event TokensReleased(address indexed beneficiary, uint256 index, uint256 amount);
    event VestingRevoked(address indexed beneficiary, uint256 index, uint256 refundedAmount);

    // ─── Constructor ─────────────────────────────────────────────

    constructor(
        string memory name_,
        string memory symbol_,
        uint256 initialSupply,
        address initialOwner
    )
        ERC20(name_, symbol_)
        ERC20Permit(name_)
        Ownable(initialOwner)
    {
        _mint(initialOwner, initialSupply);
    }

    // ─── Snapshot Functions ──────────────────────────────────────

    function snapshot() external onlyOwner returns (uint256) {
        _currentSnapshotId++;
        uint256 id = _currentSnapshotId;
        _snapshots.push(Snapshot({
            id: id,
            blockNumber: block.number,
            timestamp: block.timestamp
        }));
        emit SnapshotCreated(id, block.number);
        return id;
    }

    function getCurrentSnapshotId() external view returns (uint256) {
        return _currentSnapshotId;
    }

    function balanceOfAt(address account, uint256 snapshotId) external view returns (uint256) {
        require(snapshotId > 0 && snapshotId <= _currentSnapshotId, "Invalid snapshot id");
        if (_balanceSnapshotted[account][snapshotId]) {
            return _balanceSnapshots[account][snapshotId];
        }
        return balanceOf(account);
    }

    function totalSupplyAt(uint256 snapshotId) external view returns (uint256) {
        require(snapshotId > 0 && snapshotId <= _currentSnapshotId, "Invalid snapshot id");
        if (_totalSupplySnapshots[snapshotId] != 0) {
            return _totalSupplySnapshots[snapshotId];
        }
        return totalSupply();
    }

    function _updateSnapshot(address account) private {
        if (_currentSnapshotId > 0) {
            uint256 id = _currentSnapshotId;
            if (!_balanceSnapshotted[account][id]) {
                _balanceSnapshots[account][id] = balanceOf(account);
                _balanceSnapshotted[account][id] = true;
            }
            if (_totalSupplySnapshots[id] == 0) {
                _totalSupplySnapshots[id] = totalSupply();
            }
        }
    }

    // ─── Vesting Functions ───────────────────────────────────────

    function createVestingSchedule(
        address beneficiary,
        uint256 totalAmount,
        uint256 startTime,
        uint256 cliffDuration,
        uint256 vestingDuration,
        bool revocable
    ) external onlyOwner nonReentrant {
        require(beneficiary != address(0), "Zero address beneficiary");
        require(totalAmount > 0, "Amount must be > 0");
        require(vestingDuration > 0, "Vesting duration must be > 0");
        require(cliffDuration <= vestingDuration, "Cliff exceeds vesting");
        require(balanceOf(msg.sender) >= totalAmount, "Insufficient balance");

        uint256 start = startTime == 0 ? block.timestamp : startTime;

        _vestingSchedules[beneficiary].push(VestingSchedule({
            totalAmount: totalAmount,
            releasedAmount: 0,
            startTime: start,
            cliffEnd: start + cliffDuration,
            vestingEnd: start + vestingDuration,
            revocable: revocable,
            revoked: false
        }));

        totalVestedAmount += totalAmount;
        _transfer(msg.sender, address(this), totalAmount);

        emit VestingScheduleCreated(
            beneficiary,
            _vestingSchedules[beneficiary].length - 1,
            totalAmount,
            start,
            start + cliffDuration,
            start + vestingDuration,
            revocable
        );
    }

    function releaseVestedTokens(uint256 scheduleIndex) external nonReentrant {
        VestingSchedule storage schedule = _vestingSchedules[msg.sender][scheduleIndex];
        require(!schedule.revoked, "Schedule revoked");
        require(block.timestamp >= schedule.cliffEnd, "Cliff not reached");

        uint256 vested = _computeVestedAmount(schedule);
        uint256 releasable = vested - schedule.releasedAmount;
        require(releasable > 0, "Nothing to release");

        schedule.releasedAmount += releasable;
        totalVestedAmount -= releasable;
        _transfer(address(this), msg.sender, releasable);

        emit TokensReleased(msg.sender, scheduleIndex, releasable);
    }

    function revokeVestingSchedule(address beneficiary, uint256 scheduleIndex) external onlyOwner nonReentrant {
        VestingSchedule storage schedule = _vestingSchedules[beneficiary][scheduleIndex];
        require(schedule.revocable, "Not revocable");
        require(!schedule.revoked, "Already revoked");

        uint256 vested = _computeVestedAmount(schedule);
        uint256 releasable = vested - schedule.releasedAmount;
        uint256 refund = schedule.totalAmount - vested;

        schedule.revoked = true;
        schedule.releasedAmount += releasable;
        totalVestedAmount -= (releasable + refund);

        if (releasable > 0) {
            _transfer(address(this), beneficiary, releasable);
        }
        if (refund > 0) {
            _transfer(address(this), owner(), refund);
        }

        emit VestingRevoked(beneficiary, scheduleIndex, refund);
    }

    function getVestingSchedule(address beneficiary, uint256 index) external view returns (VestingSchedule memory) {
        return _vestingSchedules[beneficiary][index];
    }

    function getVestingScheduleCount(address beneficiary) external view returns (uint256) {
        return _vestingSchedules[beneficiary].length;
    }

    function computeReleasableAmount(address beneficiary, uint256 index) external view returns (uint256) {
        VestingSchedule storage schedule = _vestingSchedules[beneficiary][index];
        if (schedule.revoked || block.timestamp < schedule.cliffEnd) return 0;
        return _computeVestedAmount(schedule) - schedule.releasedAmount;
    }

    function _computeVestedAmount(VestingSchedule storage schedule) private view returns (uint256) {
        if (block.timestamp < schedule.cliffEnd) {
            return 0;
        } else if (block.timestamp >= schedule.vestingEnd) {
            return schedule.totalAmount;
        } else {
            uint256 elapsed = block.timestamp - schedule.startTime;
            uint256 duration = schedule.vestingEnd - schedule.startTime;
            return (schedule.totalAmount * elapsed) / duration;
        }
    }

    // ─── Pause ───────────────────────────────────────────────────

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    // ─── Overrides ───────────────────────────────────────────────

    function _update(address from, address to, uint256 value)
        internal
        override(ERC20, ERC20Votes)
        whenNotPaused
    {
        if (from != address(0)) _updateSnapshot(from);
        if (to != address(0)) _updateSnapshot(to);
        super._update(from, to, value);
    }

    function nonces(address owner_)
        public
        view
        override(ERC20Permit, Nonces)
        returns (uint256)
    {
        return super.nonces(owner_);
    }
}