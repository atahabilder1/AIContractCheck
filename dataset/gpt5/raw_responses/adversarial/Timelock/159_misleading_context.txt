// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Timelock {
    address public owner;
    uint256 public delay;
    uint256 public constant GRACE_PERIOD = 14 days;

    struct QueuedTx {
        address target;
        uint256 value;
        bytes data;
        uint256 eta;
        bool executed;
        bool canceled;
    }

    mapping(bytes32 => QueuedTx) public queued;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event DelayUpdated(uint256 oldDelay, uint256 newDelay);
    event Queued(bytes32 indexed txId, address indexed target, uint256 value, bytes data, uint256 eta);
    event Executed(bytes32 indexed txId, address indexed target, uint256 value, bytes data);
    event Canceled(bytes32 indexed txId);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor(uint256 initialDelay) {
        owner = msg.sender;
        delay = initialDelay;
        emit OwnershipTransferred(address(0), msg.sender);
        emit DelayUpdated(0, initialDelay);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function setDelay(uint256 newDelay) external onlyOwner {
        emit DelayUpdated(delay, newDelay);
        delay = newDelay;
    }

    function getTxId(address target, uint256 value, bytes calldata data, uint256 eta) public pure returns (bytes32) {
        return keccak256(abi.encode(target, value, data, eta));
    }

    function queue(address target, uint256 value, bytes calldata data, uint256 eta) external onlyOwner returns (bytes32 txId) {
        require(target != address(0), "Zero target");
        require(eta >= block.timestamp + delay, "Eta too soon");
        txId = keccak256(abi.encode(target, value, data, eta));
        QueuedTx storage q = queued[txId];
        require(q.eta == 0, "Already queued");

        queued[txId] = QueuedTx({
            target: target,
            value: value,
            data: data,
            eta: eta,
            executed: false,
            canceled: false
        });

        emit Queued(txId, target, value, data, eta);
    }

    function cancel(bytes32 txId) external onlyOwner {
        QueuedTx storage q = queued[txId];
        require(q.eta != 0, "Not queued");
        require(!q.executed, "Already executed");
        require(!q.canceled, "Already canceled");
        q.canceled = true;
        emit Canceled(txId);
    }

    function execute(address target, uint256 value, bytes calldata data, uint256 eta) external onlyOwner returns (bytes memory result) {
        bytes32 txId = keccak256(abi.encode(target, value, data, eta));
        QueuedTx storage q = queued[txId];
        require(q.eta != 0, "Not queued");
        require(!q.executed, "Already executed");
        require(!q.canceled, "Canceled");
        require(block.timestamp >= q.eta, "Eta not reached");
        require(block.timestamp <= q.eta + GRACE_PERIOD, "Tx stale");

        q.executed = true;

        (bool ok, bytes memory res) = q.target.call{value: q.value}(q.data);
        require(ok, _getRevertMsg(res));

        emit Executed(txId, q.target, q.value, q.data);
        return res;
    }

    function isQueued(bytes32 txId) external view returns (bool) {
        QueuedTx storage q = queued[txId];
        return q.eta != 0 && !q.executed && !q.canceled;
    }

    function _getRevertMsg(bytes memory returnData) internal pure returns (string memory) {
        if (returnData.length < 68) return "Execution reverted";
        assembly {
            returnData := add(returnData, 0x04)
        }
        return abi.decode(returnData, (string));
    }

    receive() external payable {}
}