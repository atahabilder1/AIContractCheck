// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
}

abstract contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status = _NOT_ENTERED;

    modifier nonReentrant() {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
}

contract Timelock is ReentrancyGuard {
    // Admin roles
    address public admin;
    address public pendingAdmin;
    address public emergencyAdmin;

    // Delay for queued transactions
    uint256 public delay;

    // Pause state
    bool public paused;

    // Bounds for delay
    uint256 public constant MIN_DELAY = 60; // 1 minute
    uint256 public constant MAX_DELAY = 30 days;

    // Queued transactions
    mapping(bytes32 => bool) public queuedTransactions;

    // Events
    event NewAdmin(address indexed newAdmin);
    event NewPendingAdmin(address indexed newPendingAdmin);
    event NewDelay(uint256 indexed newDelay);

    event QueueTransaction(
        bytes32 indexed txHash,
        address indexed target,
        uint256 value,
        string signature,
        bytes data,
        uint256 eta
    );
    event CancelTransaction(bytes32 indexed txHash, address indexed target, uint256 value, string signature, bytes data, uint256 eta);
    event ExecuteTransaction(bytes32 indexed txHash, address indexed target, uint256 value, string signature, bytes data, uint256 eta, bytes result);

    event Paused(address indexed by);
    event Unpaused(address indexed by);

    event EmergencyWithdrawETH(address indexed to, uint256 amount);
    event EmergencySweepToken(address indexed token, address indexed to, uint256 amount);
    event NewEmergencyAdmin(address indexed newEmergencyAdmin);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Timelock: caller is not admin");
        _;
    }

    modifier onlyEmergencyAdmin() {
        require(msg.sender == emergencyAdmin, "Timelock: caller is not emergency admin");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "Timelock: paused");
        _;
    }

    constructor(address admin_, address emergencyAdmin_, uint256 delay_) {
        require(admin_ != address(0), "Timelock: zero admin");
        require(emergencyAdmin_ != address(0), "Timelock: zero emergency admin");
        require(delay_ >= MIN_DELAY && delay_ <= MAX_DELAY, "Timelock: invalid delay");
        admin = admin_;
        emergencyAdmin = emergencyAdmin_;
        delay = delay_;
        emit NewAdmin(admin_);
        emit NewEmergencyAdmin(emergencyAdmin_);
        emit NewDelay(delay_);
    }

    receive() external payable {}

    // Admin management
    function setPendingAdmin(address pendingAdmin_) external onlyAdmin whenNotPaused {
        require(pendingAdmin_ != address(0), "Timelock: zero pending admin");
        pendingAdmin = pendingAdmin_;
        emit NewPendingAdmin(pendingAdmin_);
    }

    function acceptAdmin() external whenNotPaused {
        require(msg.sender == pendingAdmin, "Timelock: caller is not pending admin");
        admin = pendingAdmin;
        pendingAdmin = address(0);
        emit NewAdmin(admin);
    }

    function setEmergencyAdmin(address emergencyAdmin_) external onlyAdmin whenNotPaused {
        require(emergencyAdmin_ != address(0), "Timelock: zero emergency admin");
        emergencyAdmin = emergencyAdmin_;
        emit NewEmergencyAdmin(emergencyAdmin_);
    }

    function setDelay(uint256 delay_) external onlyAdmin whenNotPaused {
        require(delay_ >= MIN_DELAY && delay_ <= MAX_DELAY, "Timelock: invalid delay");
        delay = delay_;
        emit NewDelay(delay_);
    }

    // Pause controls (emergency)
    function emergencyPause() external onlyEmergencyAdmin {
        require(!paused, "Timelock: already paused");
        paused = true;
        emit Paused(msg.sender);
    }

    function emergencyUnpause() external onlyEmergencyAdmin {
        require(paused, "Timelock: not paused");
        paused = false;
        emit Unpaused(msg.sender);
    }

    // Queue, cancel, execute
    function queueTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) external onlyAdmin whenNotPaused returns (bytes32) {
        require(target != address(0), "Timelock: zero target");
        require(eta >= block.timestamp + delay, "Timelock: eta too soon");

        bytes32 txHash = getTxHash(target, value, signature, data, eta);
        queuedTransactions[txHash] = true;

        emit QueueTransaction(txHash, target, value, signature, data, eta);
        return txHash;
    }

    function cancelTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) external onlyAdmin whenNotPaused {
        bytes32 txHash = getTxHash(target, value, signature, data, eta);
        require(queuedTransactions[txHash], "Timelock: not queued");
        queuedTransactions[txHash] = false;

        emit CancelTransaction(txHash, target, value, signature, data, eta);
    }

    function executeTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) external nonReentrant whenNotPaused returns (bytes memory) {
        bytes32 txHash = getTxHash(target, value, signature, data, eta);
        require(queuedTransactions[txHash], "Timelock: not queued");
        require(block.timestamp >= eta, "Timelock: not ready");

        queuedTransactions[txHash] = false;

        bytes memory callData;
        if (bytes(signature).length == 0) {
            callData = data;
        } else {
            callData = abi.encodePacked(bytes4(keccak256(bytes(signature))), data);
        }

        (bool success, bytes memory result) = target.call{value: value}(callData);
        require(success, _getRevertMsg(result));

        emit ExecuteTransaction(txHash, target, value, signature, data, eta, result);
        return result;
    }

    // Emergency fund recovery
    function emergencyWithdrawETH(address payable to) external onlyEmergencyAdmin nonReentrant {
        require(to != address(0), "Timelock: zero to");
        uint256 amount = address(this).balance;
        (bool ok, ) = to.call{value: amount}("");
        require(ok, "Timelock: ETH transfer failed");
        emit EmergencyWithdrawETH(to, amount);
    }

    function emergencySweepToken(address token, address to) external onlyEmergencyAdmin nonReentrant {
        require(token != address(0), "Timelock: zero token");
        require(to != address(0), "Timelock: zero to");
        uint256 amount = IERC20(token).balanceOf(address(this));
        require(IERC20(token).transfer(to, amount), "Timelock: token transfer failed");
        emit EmergencySweepToken(token, to, amount);
    }

    // Helpers
    function getTxHash(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) public pure returns (bytes32) {
        return keccak256(abi.encode(target, value, signature, data, eta));
    }

    function _getRevertMsg(bytes memory returnData) internal pure returns (string memory) {
        if (returnData.length < 68) return "Timelock: execution reverted";
        assembly {
            returnData := add(returnData, 0x04)
        }
        return abi.decode(returnData, (string));
    }
}