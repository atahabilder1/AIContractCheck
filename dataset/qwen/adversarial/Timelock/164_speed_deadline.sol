// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Timelock {
    address public admin;
    uint256 public minDelay;

    event NewAdmin(address indexed newAdmin);
    event NewDelay(uint256 indexed newDelay);
    event QueueTransaction(
        bytes32 indexed txHash,
        address indexed target,
        uint256 value,
        string signature,
        bytes data,
        uint256 eta
    );
    event ExecuteTransaction(
        bytes32 indexed txHash,
        address indexed target,
        uint256 value,
        string signature,
        bytes data,
        uint256 eta
    );
    event CancelTransaction(bytes32 indexed txHash);

    mapping(bytes32 => bool) public queuedTransactions;

    constructor(address admin_, uint256 minDelay_) {
        require(minDelay_ >= 0, "Timelock::constructor: Delay must be nonnegative");
        admin = admin_;
        minDelay = minDelay_;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Timelock::onlyAdmin: sender must be admin");
        _;
    }

    function setDelay(uint256 delay_) public onlyAdmin {
        require(delay_ >= 0, "Timelock::setDelay: Delay must be nonnegative");
        minDelay = delay_;
        emit NewDelay(delay_);
    }

    function acceptAdmin() public {
        require(msg.sender == admin, "Timelock::acceptAdmin: Call must come from admin");
        emit NewAdmin(admin);
    }

    function queueTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) public onlyAdmin returns (bytes32 txHash) {
        require(eta >= getBlockTimestamp() + minDelay, "Timelock::queueTransaction: Estimated execution block must satisfy delay.");

        txHash = keccak256(abi.encode(target, value, signature, data, eta));
        queuedTransactions[txHash] = true;

        emit QueueTransaction(txHash, target, value, signature, data, eta);
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
        require(queuedTransactions[txHash], "Timelock::executeTransaction: Transaction hasn't been queued.");
        require(getBlockTimestamp() >= eta, "Timelock::executeTransaction: Transaction hasn't surpassed time lock.");
        require(getBlockTimestamp() <= eta + minDelay, "Timelock::executeTransaction: Transaction is stale.");

        queuedTransactions[txHash] = false;

        bytes memory callData;

        if (bytes(signature).length == 0) {
            callData = data;
        } else {
            callData = abi.encodePacked(bytes4(keccak256(bytes(signature))), data);
        }

        // solium-disable-next-line security/no-call-value
        (bool success, bytes memory returnData) = target.call{value: value}(callData);
        require(success, "Timelock::executeTransaction: Transaction execution reverted.");

        emit ExecuteTransaction(txHash, target, value, signature, data, eta);

        return returnData;
    }

    function getBlockTimestamp() internal view returns (uint256) {
        // solium-disable-next-line security/no-block-members
        return block.timestamp;
    }
}