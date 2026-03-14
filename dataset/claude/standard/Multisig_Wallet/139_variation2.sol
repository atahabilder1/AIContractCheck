// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract SocialRecoveryWallet {
    address public owner;
    uint256 public threshold;

    mapping(address => bool) public isGuardian;
    address[] public guardians;

    struct RecoveryRequest {
        address newOwner;
        uint256 approvalCount;
        mapping(address => bool) hasApproved;
        bool executed;
    }

    uint256 public activeRecoveryRound;
    mapping(uint256 => RecoveryRequest) private recoveryRequests;

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier onlyGuardian() {
        require(isGuardian[msg.sender], "Not guardian");
        _;
    }

    event RecoveryInitiated(uint256 indexed round, address indexed proposedOwner, address indexed guardian);
    event RecoverySupported(uint256 indexed round, address indexed guardian);
    event RecoveryExecuted(uint256 indexed round, address indexed oldOwner, address indexed newOwner);
    event GuardianAdded(address indexed guardian);
    event GuardianRemoved(address indexed guardian);
    event Deposited(address indexed sender, uint256 amount);
    event Executed(address indexed target, uint256 value, bytes data);

    constructor(address[] memory _guardians, uint256 _threshold) {
        require(_guardians.length >= _threshold, "Threshold exceeds guardian count");
        require(_threshold > 0, "Threshold must be > 0");

        owner = msg.sender;
        threshold = _threshold;

        for (uint256 i = 0; i < _guardians.length; i++) {
            address g = _guardians[i];
            require(g != address(0), "Zero address guardian");
            require(!isGuardian[g], "Duplicate guardian");
            isGuardian[g] = true;
            guardians.push(g);
        }
    }

    receive() external payable {
        emit Deposited(msg.sender, msg.value);
    }

    function execute(address _target, uint256 _value, bytes calldata _data) external onlyOwner returns (bytes memory) {
        (bool success, bytes memory result) = _target.call{value: _value}(_data);
        require(success, "Execution failed");
        emit Executed(_target, _value, _data);
        return result;
    }

    function initiateRecovery(address _newOwner) external onlyGuardian {
        require(_newOwner != address(0), "Zero address");
        activeRecoveryRound++;
        RecoveryRequest storage req = recoveryRequests[activeRecoveryRound];
        req.newOwner = _newOwner;
        req.approvalCount = 1;
        req.hasApproved[msg.sender] = true;

        emit RecoveryInitiated(activeRecoveryRound, _newOwner, msg.sender);
    }

    function supportRecovery(uint256 _round) external onlyGuardian {
        RecoveryRequest storage req = recoveryRequests[_round];
        require(req.newOwner != address(0), "No active request");
        require(!req.executed, "Already executed");
        require(!req.hasApproved[msg.sender], "Already approved");

        req.hasApproved[msg.sender] = true;
        req.approvalCount++;

        emit RecoverySupported(_round, msg.sender);

        if (req.approvalCount >= threshold) {
            req.executed = true;
            address oldOwner = owner;
            owner = req.newOwner;
            emit RecoveryExecuted(_round, oldOwner, req.newOwner);
        }
    }

    function addGuardian(address _guardian) external onlyOwner {
        require(_guardian != address(0), "Zero address");
        require(!isGuardian[_guardian], "Already guardian");
        isGuardian[_guardian] = true;
        guardians.push(_guardian);
        emit GuardianAdded(_guardian);
    }

    function removeGuardian(address _guardian) external onlyOwner {
        require(isGuardian[_guardian], "Not guardian");
        isGuardian[_guardian] = false;
        for (uint256 i = 0; i < guardians.length; i++) {
            if (guardians[i] == _guardian) {
                guardians[i] = guardians[guardians.length - 1];
                guardians.pop();
                break;
            }
        }
        require(guardians.length >= threshold, "Below threshold");
        emit GuardianRemoved(_guardian);
    }

    function setThreshold(uint256 _threshold) external onlyOwner {
        require(_threshold > 0 && _threshold <= guardians.length, "Invalid threshold");
        threshold = _threshold;
    }

    function getGuardians() external view returns (address[] memory) {
        return guardians;
    }

    function getRecoveryInfo(uint256 _round) external view returns (address newOwner, uint256 approvalCount, bool executed) {
        RecoveryRequest storage req = recoveryRequests[_round];
        return (req.newOwner, req.approvalCount, req.executed);
    }

    function hasGuardianApproved(uint256 _round, address _guardian) external view returns (bool) {
        return recoveryRequests[_round].hasApproved[_guardian];
    }
}