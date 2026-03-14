// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract CrossChainBridge {
    address public admin;
    bool public paused;

    mapping(bytes32 => bool) public processedTransfers;
    mapping(address => uint256) public nonces;

    uint256 public bridgeFee = 0.001 ether;
    uint256 public minTransfer = 0.01 ether;
    uint256 public maxTransfer = 100 ether;

    event Deposit(
        address indexed sender,
        address indexed recipient,
        uint256 amount,
        uint256 destChainId,
        uint256 nonce,
        uint256 timestamp
    );
    event Withdrawal(
        address indexed recipient,
        uint256 amount,
        bytes32 indexed transferId
    );
    event Paused(address indexed by);
    event Unpaused(address indexed by);
    event EmergencyWithdraw(address indexed by, uint256 amount);
    event AdminChanged(address indexed oldAdmin, address indexed newAdmin);
    event FeeUpdated(uint256 newFee);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Not admin");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "Bridge is paused");
        _;
    }

    constructor() {
        admin = msg.sender;
    }

    function deposit(address _recipient, uint256 _destChainId) external payable whenNotPaused {
        require(msg.value > bridgeFee, "Amount must exceed fee");
        uint256 transferAmount = msg.value - bridgeFee;
        require(transferAmount >= minTransfer, "Below minimum transfer");
        require(transferAmount <= maxTransfer, "Exceeds maximum transfer");
        require(_recipient != address(0), "Invalid recipient");
        require(_destChainId != block.chainid, "Same chain transfer");

        uint256 nonce = nonces[msg.sender]++;

        emit Deposit(msg.sender, _recipient, transferAmount, _destChainId, nonce, block.timestamp);
    }

    function withdraw(
        address payable _recipient,
        uint256 _amount,
        bytes32 _transferId
    ) external onlyAdmin whenNotPaused {
        require(!processedTransfers[_transferId], "Already processed");
        require(_recipient != address(0), "Invalid recipient");
        require(address(this).balance >= _amount, "Insufficient balance");

        processedTransfers[_transferId] = true;

        (bool success, ) = _recipient.call{value: _amount}("");
        require(success, "Transfer failed");

        emit Withdrawal(_recipient, _amount, _transferId);
    }

    // --- Emergency Admin Functions ---

    function pause() external onlyAdmin {
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyAdmin {
        paused = false;
        emit Unpaused(msg.sender);
    }

    function emergencyWithdraw() external onlyAdmin {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds");

        paused = true;

        (bool success, ) = payable(admin).call{value: balance}("");
        require(success, "Transfer failed");

        emit EmergencyWithdraw(msg.sender, balance);
    }

    function emergencyWithdrawPartial(uint256 _amount) external onlyAdmin {
        require(address(this).balance >= _amount, "Insufficient balance");

        (bool success, ) = payable(admin).call{value: _amount}("");
        require(success, "Transfer failed");

        emit EmergencyWithdraw(msg.sender, _amount);
    }

    function setAdmin(address _newAdmin) external onlyAdmin {
        require(_newAdmin != address(0), "Invalid address");
        emit AdminChanged(admin, _newAdmin);
        admin = _newAdmin;
    }

    function setBridgeFee(uint256 _fee) external onlyAdmin {
        bridgeFee = _fee;
        emit FeeUpdated(_fee);
    }

    function setTransferLimits(uint256 _min, uint256 _max) external onlyAdmin {
        require(_min < _max, "Invalid limits");
        minTransfer = _min;
        maxTransfer = _max;
    }

    receive() external payable {}
}