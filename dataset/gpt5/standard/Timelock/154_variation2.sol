// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract ProportionalValueTimelock {
    // ============ Events ============
    event Scheduled(
        uint256 indexed id,
        address indexed proposer,
        address indexed target,
        uint256 value,
        uint256 executeAfter,
        bytes data
    );
    event Executed(uint256 indexed id, address indexed executor, bytes returnData);
    event Canceled(uint256 indexed id, address indexed canceller);
    event BaseDelayUpdated(uint256 oldDelay, uint256 newDelay);
    event SlopeUpdated(uint256 oldSlope, uint256 newSlope);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // ============ Errors ============
    error NotOwner();
    error NotProposer();
    error InvalidTarget();
    error OperationNotFound();
    error OperationExecuted();
    error OperationCanceled();
    error NotReady();
    error RefundFailed();
    error DirectFundingNotAllowed();

    // ============ Modifiers ============
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier nonReentrant() {
        if (_locked) revert();
        _locked = true;
        _;
        _locked = false;
    }

    // ============ Storage ============
    struct Operation {
        address proposer;
        address target;
        uint256 value;
        uint256 executeAfter;
        bool executed;
        bool canceled;
        bytes data;
    }

    mapping(uint256 => Operation) private _ops;
    uint256 public nextOperationId;

    // delay = baseDelay + (valueWei * slopeSecondsPerEther / 1 ether)
    uint256 public baseDelay; // seconds
    uint256 public slopeSecondsPerEther; // seconds per 1 ether

    address public owner;
    bool private _locked;

    // ============ Constructor ============
    constructor(uint256 _baseDelay, uint256 _slopeSecondsPerEther) {
        owner = msg.sender;
        baseDelay = _baseDelay;
        slopeSecondsPerEther = _slopeSecondsPerEther;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    // ============ Admin ============
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Zero owner");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function setBaseDelay(uint256 newBaseDelay) external onlyOwner {
        emit BaseDelayUpdated(baseDelay, newBaseDelay);
        baseDelay = newBaseDelay;
    }

    function setSlopeSecondsPerEther(uint256 newSlope) external onlyOwner {
        emit SlopeUpdated(slopeSecondsPerEther, newSlope);
        slopeSecondsPerEther = newSlope;
    }

    // ============ Public View ============
    function computeDelay(uint256 valueWei) public view returns (uint256) {
        // baseDelay + (valueWei * slopeSecondsPerEther) / 1 ether
        if (slopeSecondsPerEther == 0) return baseDelay;
        unchecked {
            // Using unchecked for mul to save gas; overflow is unlikely given realistic parameters
            uint256 variableDelay = (valueWei * slopeSecondsPerEther) / 1 ether;
            return baseDelay + variableDelay;
        }
    }

    function getOperation(uint256 id)
        external
        view
        returns (
            address proposer,
            address target,
            uint256 value,
            uint256 executeAfter,
            bool executed,
            bool canceled,
            bytes memory data
        )
    {
        Operation storage op = _ops[id];
        if (op.proposer == address(0)) revert OperationNotFound();
        return (op.proposer, op.target, op.value, op.executeAfter, op.executed, op.canceled, op.data);
    }

    // ============ Core Logic ============
    // Schedule a transaction. The ETH sent (msg.value) will be forwarded to the target upon execution.
    function schedule(address target, bytes calldata data) external payable returns (uint256 id) {
        if (target == address(0)) revert InvalidTarget();

        uint256 delay = computeDelay(msg.value);
        uint256 executeAfter = block.timestamp + delay;

        id = nextOperationId++;
        _ops[id] = Operation({
            proposer: msg.sender,
            target: target,
            value: msg.value,
            executeAfter: executeAfter,
            executed: false,
            canceled: false,
            data: data
        });

        emit Scheduled(id, msg.sender, target, msg.value, executeAfter, data);
    }

    // Execute a scheduled operation after its timelock expires.
    function execute(uint256 id) external nonReentrant returns (bytes memory returnData) {
        Operation storage op = _ops[id];
        if (op.proposer == address(0)) revert OperationNotFound();
        if (op.executed) revert OperationExecuted();
        if (op.canceled) revert OperationCanceled();
        if (block.timestamp < op.executeAfter) revert NotReady();

        (bool ok, bytes memory ret) = op.target.call{value: op.value}(op.data);
        require(ok, _bubble(ret));

        op.executed = true;
        emit Executed(id, msg.sender, ret);
        return ret;
    }

    // Cancel a scheduled operation before execution; refunds ETH to the proposer.
    function cancel(uint256 id) external nonReentrant {
        Operation storage op = _ops[id];
        if (op.proposer == address(0)) revert OperationNotFound();
        if (op.executed) revert OperationExecuted();
        if (op.canceled) revert OperationCanceled();
        if (msg.sender != op.proposer && msg.sender != owner) revert NotProposer();

        op.canceled = true;

        uint256 refund = op.value;
        if (refund > 0) {
            op.value = 0; // prevent double-withdraw on unexpected reentrancy
            (bool ok, ) = op.proposer.call{value: refund}("");
            if (!ok) revert RefundFailed();
        }

        emit Canceled(id, msg.sender);
    }

    // ============ Receive / Fallback ============
    receive() external payable {
        revert DirectFundingNotAllowed();
    }

    fallback() external payable {
        revert DirectFundingNotAllowed();
    }

    // ============ Internal Helpers ============
    function _bubble(bytes memory revertData) internal pure returns (string memory) {
        // If revertData is empty, return generic message
        if (revertData.length < 68) {
            return "Underlying call failed";
        }
        // Slice the revert reason out of the revert data
        assembly {
            revertData := add(revertData, 0x04)
        }
        return abi.decode(revertData, (string));
    }
}