// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract TimelockWithFastTrack {
    address public admin;
    uint256 public delay;
    uint256 public fastTrackThreshold;
    address[] public guardians;
    mapping(bytes32 => bool) public queuedTransactions;
    mapping(bytes32 => uint256) public guardianApprovals;

    event QueueTransaction(bytes32 indexed txHash, address indexed target, uint256 value, string signature, bytes data, uint256 eta);
    event ExecuteTransaction(bytes32 indexed txHash, address indexed target, uint256 value, string signature, bytes data);
    event CancelTransaction(bytes32 indexed txHash, address indexed target, uint256 value, string signature, bytes data);
    event ApproveFastTrack(bytes32 indexed txHash, address indexed guardian);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Timelock: caller is not the admin");
        _;
    }

    modifier onlyGuardian() {
        bool isGuardian = false;
        for (uint256 i = 0; i < guardians.length; i++) {
            if (guardians[i] == msg.sender) {
                isGuardian = true;
                break;
            }
        }
        require(isGuardian, "Timelock: caller is not a guardian");
        _;
    }

    constructor(address _admin, uint256 _delay, address[] memory _guardians, uint256 _fastTrackThreshold) {
        admin = _admin;
        delay = _delay;
        guardians = _guardians;
        fastTrackThreshold = _fastTrackThreshold;
    }

    function queueTransaction(address target, uint256 value, string memory signature, bytes memory data, uint256 eta) public onlyAdmin returns (bytes32) {
        require(eta >= block.timestamp + delay, "Timelock: ETA must satisfy delay");
        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
        queuedTransactions[txHash] = true;

        emit QueueTransaction(txHash, target, value, signature, data, eta);
        return txHash;
    }

    function cancelTransaction(address target, uint256 value, string memory signature, bytes memory data, uint256 eta) public onlyAdmin {
        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
        queuedTransactions[txHash] = false;

        emit CancelTransaction(txHash, target, value, signature, data);
    }

    function approveFastTrack(bytes32 txHash) public onlyGuardian {
        require(queuedTransactions[txHash], "Timelock: transaction is not queued");
        guardianApprovals[txHash] += 1;
        emit ApproveFastTrack(txHash, msg.sender);
    }

    function executeTransaction(address target, uint256 value, string memory signature, bytes memory data, uint256 eta) public payable onlyAdmin returns (bytes memory) {
        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
        require(queuedTransactions[txHash], "Timelock: transaction is not queued");
        
        if (guardianApprovals[txHash] >= fastTrackThreshold) {
            // Fast-track execution approved by supermajority
            delete queuedTransactions[txHash];
        } else {
            require(block.timestamp >= eta, "Timelock: transaction hasn't surpassed time lock");
            delete queuedTransactions[txHash];
        }

        bytes memory callData;

        if (bytes(signature).length == 0) {
            callData = data;
        } else {
            callData = abi.encodePacked(bytes4(keccak256(bytes(signature))), data);
        }

        (bool success, bytes memory returnData) = target.call{value: value}(callData);
        require(success, "Timelock: transaction execution reverted");

        emit ExecuteTransaction(txHash, target, value, signature, data);
        return returnData;
    }
}