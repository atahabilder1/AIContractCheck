// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SocialRecoveryWallet is ReentrancyGuard {
    using SafeERC20 for IERC20;

    address public owner;
    address[] public guardians;
    mapping(address => bool) public isGuardian;
    uint256 public threshold;
    uint256 public recoveryDelay;
    
    struct RecoveryRequest {
        address newOwner;
        uint256 approvalCount;
        uint256 requestTime;
        bool executed;
        mapping(address => bool) approvals;
    }
    
    RecoveryRequest public activeRecovery;
    bool public recoveryInProgress;
    
    event OwnerChanged(address indexed previousOwner, address indexed newOwner);
    event GuardianAdded(address indexed guardian);
    event GuardianRemoved(address indexed guardian);
    event RecoveryRequested(address indexed newOwner, uint256 requestTime);
    event RecoveryApproved(address indexed guardian, address indexed newOwner);
    event RecoveryExecuted(address indexed newOwner);
    event RecoveryCancelled();
    event EtherReceived(address indexed from, uint256 amount);
    event EtherSent(address indexed to, uint256 amount);
    event TokenSent(address indexed token, address indexed to, uint256 amount);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }
    
    modifier onlyGuardian() {
        require(isGuardian[msg.sender], "Not a guardian");
        _;
    }
    
    modifier noActiveRecovery() {
        require(!recoveryInProgress, "Recovery in progress");
        _;
    }
    
    modifier validAddress(address _addr) {
        require(_addr != address(0), "Zero address not allowed");
        _;
    }
    
    constructor(
        address _owner,
        address[] memory _guardians,
        uint256 _threshold,
        uint256 _recoveryDelay
    ) validAddress(_owner) {
        require(_guardians.length > 0, "Must have at least one guardian");
        require(_threshold > 0 && _threshold <= _guardians.length, "Invalid threshold");
        require(_recoveryDelay > 0, "Recovery delay must be positive");
        
        owner = _owner;
        threshold = _threshold;
        recoveryDelay = _recoveryDelay;
        
        for (uint256 i = 0; i < _guardians.length; i++) {
            address guardian = _guardians[i];
            require(guardian != address(0), "Guardian cannot be zero address");
            require(guardian != _owner, "Owner cannot be guardian");
            require(!isGuardian[guardian], "Duplicate guardian");
            
            guardians.push(guardian);
            isGuardian[guardian] = true;
            emit GuardianAdded(guardian);
        }
    }
    
    receive() external payable {
        emit EtherReceived(msg.sender, msg.value);
    }
    
    function addGuardian(address _guardian) 
        external 
        onlyOwner 
        noActiveRecovery 
        validAddress(_guardian) 
    {
        require(_guardian != owner, "Owner cannot be guardian");
        require(!isGuardian[_guardian], "Already a guardian");
        
        guardians.push(_guardian);
        isGuardian[_guardian] = true;
        emit GuardianAdded(_guardian);
    }
    
    function removeGuardian(address _guardian) 
        external 
        onlyOwner 
        noActiveRecovery 
    {
        require(isGuardian[_guardian], "Not a guardian");
        require(guardians.length > threshold, "Cannot remove guardian below threshold");
        
        isGuardian[_guardian] = false;
        
        for (uint256 i = 0; i < guardians.length; i++) {
            if (guardians[i] == _guardian) {
                guardians[i] = guardians[guardians.length - 1];
                guardians.pop();
                break;
            }
        }
        
        emit GuardianRemoved(_guardian);
    }
    
    function updateThreshold(uint256 _newThreshold) 
        external 
        onlyOwner 
        noActiveRecovery 
    {
        require(_newThreshold > 0 && _newThreshold <= guardians.length, "Invalid threshold");
        threshold = _newThreshold;
    }
    
    function requestRecovery(address _newOwner) 
        external 
        onlyGuardian 
        validAddress(_newOwner) 
    {
        require(!recoveryInProgress, "Recovery already in progress");
        require(_newOwner != owner, "New owner cannot be current owner");
        
        recoveryInProgress = true;
        activeRecovery.newOwner = _newOwner;
        activeRecovery.approvalCount = 1;
        activeRecovery.requestTime = block.timestamp;
        activeRecovery.executed = false;
        activeRecovery.approvals[msg.sender] = true;
        
        emit RecoveryRequested(_newOwner, block.timestamp);
        emit RecoveryApproved(msg.sender, _newOwner);
    }
    
    function approveRecovery() external onlyGuardian {
        require(recoveryInProgress, "No active recovery");
        require(!activeRecovery.executed, "Recovery already executed");
        require(!activeRecovery.approvals[msg.sender], "Already approved");
        
        activeRecovery.approvals[msg.sender] = true;
        activeRecovery.approvalCount++;
        
        emit RecoveryApproved(msg.sender, activeRecovery.newOwner);
    }
    
    function executeRecovery() external nonReentrant {
        require(recoveryInProgress, "No active recovery");
        require(!activeRecovery.executed, "Recovery already executed");
        require(activeRecovery.approvalCount >= threshold, "Insufficient approvals");
        require(
            block.timestamp >= activeRecovery.requestTime + recoveryDelay,
            "Recovery delay not met"
        );
        
        activeRecovery.executed = true;
        address previousOwner = owner;
        owner = activeRecovery.newOwner;
        
        _resetRecovery();
        
        emit RecoveryExecuted(activeRecovery.newOwner);
        emit OwnerChanged(previousOwner, owner);
    }
    
    function cancelRecovery() external onlyOwner {
        require(recoveryInProgress, "No active recovery");
        _resetRecovery();
        emit RecoveryCancelled();
    }
    
    function _resetRecovery() private {
        recoveryInProgress = false;
        delete activeRecovery;
    }
    
    function sendEther(address payable _to, uint256 _amount) 
        external 
        onlyOwner 
        nonReentrant 
        validAddress(_to) 
    {
        require(_amount > 0, "Amount must be positive");
        require(address(this).balance >= _amount, "Insufficient balance");
        
        (bool success, ) = _to.call{value: _amount}("");
        require(success, "Ether transfer failed");
        
        emit EtherSent(_to, _amount);
    }
    
    function sendToken(
        address _token, 
        address _to, 
        uint256 _amount
    ) 
        external 
        onlyOwner 
        nonReentrant 
        validAddress(_token) 
        validAddress(_to) 
    {
        require(_amount > 0, "Amount must be positive");
        
        IERC20(_token).safeTransfer(_to, _amount);
        
        emit TokenSent(_token, _to, _amount);
    }
    
    function getGuardians() external view returns (address[] memory) {
        return guardians;
    }
    
    function getRecoveryInfo() external view returns (
        address newOwner,
        uint256 approvalCount,
        uint256 requestTime,
        bool executed,
        bool inProgress
    ) {
        return (
            activeRecovery.newOwner,
            activeRecovery.approvalCount,
            activeRecovery.requestTime,
            activeRecovery.executed,
            recoveryInProgress
        );
    }
    
    function hasApprovedRecovery(address _guardian) external view returns (bool) {
        return activeRecovery.approvals[_guardian];
    }
    
    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
    
    function getTokenBalance(address _token) external view returns (uint256) {
        return IERC20(_token).balanceOf(address(this));
    }
}