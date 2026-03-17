// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract Timelock {
    // Errors
    error NotAdmin();
    error AlreadyQueued();
    error NotQueued();
    error TimeNotElapsed();
    error CallFailed();

    // Storage (packed: admin + delay)
    address public admin;
    uint32 public delay;

    // Operation id => executeAt (0 means not queued)
    mapping(bytes32 => uint40) public etaOf;

    // Events
    event Queued(bytes32 indexed id, address indexed target, uint256 value, uint40 executeAt);
    event Executed(bytes32 indexed id, address indexed target, uint256 value);
    event Canceled(bytes32 indexed id);
    event AdminChanged(address indexed oldAdmin, address indexed newAdmin);
    event DelayChanged(uint32 oldDelay, uint32 newDelay);

    constructor(uint32 initialDelay) {
        admin = msg.sender;
        delay = initialDelay;
    }

    function hashOperation(address target, uint256 value, bytes calldata data) public pure returns (bytes32) {
        return keccak256(abi.encode(target, value, keccak256(data)));
    }

    function queue(address target, uint256 value, bytes calldata data) external returns (bytes32 id, uint40 eta) {
        if (msg.sender != admin) revert NotAdmin();
        id = keccak256(abi.encode(target, value, keccak256(data)));
        if (etaOf[id] != 0) revert AlreadyQueued();
        unchecked {
            eta = uint40(block.timestamp + uint256(delay));
        }
        etaOf[id] = eta;
        emit Queued(id, target, value, eta);
    }

    function cancel(bytes32 id) external {
        if (msg.sender != admin) revert NotAdmin();
        if (etaOf[id] == 0) revert NotQueued();
        delete etaOf[id];
        emit Canceled(id);
    }

    function execute(address target, uint256 value, bytes calldata data) external payable returns (bytes memory result) {
        if (msg.sender != admin) revert NotAdmin();
        bytes32 id = keccak256(abi.encode(target, value, keccak256(data)));
        uint40 eta = etaOf[id];
        if (eta == 0) revert NotQueued();
        if (block.timestamp < uint256(eta)) revert TimeNotElapsed();

        delete etaOf[id];

        (bool ok, bytes memory res) = target.call{value: value}(data);
        if (!ok) revert CallFailed();

        emit Executed(id, target, value);
        return res;
    }

    function setAdmin(address newAdmin) external {
        if (msg.sender != admin) revert NotAdmin();
        emit AdminChanged(admin, newAdmin);
        admin = newAdmin;
    }

    function setDelay(uint32 newDelay) external {
        if (msg.sender != admin) revert NotAdmin();
        emit DelayChanged(delay, newDelay);
        delay = newDelay;
    }

    receive() external payable {}
}