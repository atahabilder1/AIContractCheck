// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Timelock {
    uint256 public constant MINIMUM_DELAY = 1 days;
    uint256 public constant MAXIMUM_DELAY = 30 days;
    uint256 public constant GRACE_PERIOD = 14 days;

    address public admin;
    uint256 public delay;
    uint256 public gracePeriod;

    mapping(bytes32 => bool) public queuedTransactions;

    event QueueTransaction(bytes32 txHash, address target, uint256 value, string signature, bytes data, uint256 eta);
    event ExecuteTransaction(bytes32 txHash, address target, uint256 value, string signature, bytes data, uint256 eta);
    event CancelTransaction(bytes32 txHash);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Timelock::onlyAdmin: caller is not the admin");
        _;
    }

    constructor(uint256 _delay) {
        require(_delay >= MINIMUM_DELAY && _delay <= MAXIMUM_DELAY, "Timelock::constructor: invalid delay");
        admin = msg.sender;
        delay = _delay;
        gracePeriod = GRACE_PERIOD;
    }

    receive() external payable {}

    function queueTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) public onlyAdmin returns (bytes32) {
        require(eta >= getBlockTimestamp() + delay, "Timelock::queueTransaction: Estimated execution block must satisfy delay.");
        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
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
    ) public onlyAdmin {
        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
        queuedTransactions[txHash] = false;
        emit CancelTransaction(txHash);
    }

    function executeTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) public payable onlyAdmin returns (bytes memory) {
        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
        require(queuedTransactions[txHash], "Timelock::executeTransaction: transaction hasn't been queued.");
        require(getBlockTimestamp() >= eta, "Timelock::executeTransaction: transaction hasn't surpassed time lock.");
        require(getBlockTimestamp() <= eta + gracePeriod, "Timelock::executeTransaction: transaction is stale.");
        queuedTransactions[txHash] = false;

        bytes memory callData;
        if (bytes(signature).length == 0) {
            callData = data;
        } else {
            callData = abi.encodePacked(bytes4(keccak256(bytes(signature))), data);
        }

        (bool success, bytes memory returnData) = target.call{value: value}(callData);
        require(success, "Timelock::executeTransaction: Transaction execution reverted.");
        emit ExecuteTransaction(txHash, target, value, signature, data, eta);
        return returnData;
    }

    function getBlockTimestamp() internal view returns (uint256) {
        return block.timestamp;
    }
}