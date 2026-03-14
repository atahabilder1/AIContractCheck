// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Timelock {
    address public admin;
    uint256 public delay;

    struct Operation {
        bool executed;
        uint256 eta;
    }

    mapping(bytes32 => Operation) public operations;

    event OperationScheduled(bytes32 indexed id, uint256 eta);
    event OperationExecuted(bytes32 indexed id);
    event OperationCancelled(bytes32 indexed id);
    event NewAdmin(address indexed newAdmin);
    event NewDelay(uint256 indexed newDelay);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Timelock::onlyAdmin: caller is not the admin");
        _;
    }

    constructor(uint256 _delay, address _admin) {
        require(_delay > 0, "Timelock::constructor: Delay must be greater than 0");
        admin = _admin;
        delay = _delay;
    }

    function setDelay(uint256 _delay) external onlyAdmin {
        require(_delay > 0, "Timelock::setDelay: Delay must be greater than 0");
        delay = _delay;
        emit NewDelay(delay);
    }

    function setAdmin(address _admin) external onlyAdmin {
        require(_admin != address(0), "Timelock::setAdmin: Admin cannot be the zero address");
        admin = _admin;
        emit NewAdmin(admin);
    }

    function schedule(
        address target,
        uint256 value,
        bytes calldata data,
        uint256 eta
    ) external onlyAdmin returns (bytes32) {
        require(eta >= block.timestamp + delay, "Timelock::schedule: Estimated execution block must satisfy delay.");

        bytes32 id = keccak256(abi.encode(target, value, data, eta));
        require(operations[id].eta == 0, "Timelock::schedule: Operation already scheduled");

        operations[id] = Operation(false, eta);
        emit OperationScheduled(id, eta);
        return id;
    }

    function execute(
        address target,
        uint256 value,
        bytes calldata data,
        uint256 eta
    ) external payable onlyAdmin returns (bytes memory) {
        bytes32 id = keccak256(abi.encode(target, value, data, eta));
        require(operations[id].eta != 0, "Timelock::execute: Operation hasn't been scheduled");
        require(block.timestamp >= operations[id].eta, "Timelock::execute: Operation hasn't reached its eta");
        require(!operations[id].executed, "Timelock::execute: Operation has already been executed");

        operations[id].executed = true;
        (bool success, bytes memory result) = target.call{value: value}(data);
        require(success, "Timelock::execute: Execution reverted");

        emit OperationExecuted(id);
        return result;
    }

    function cancel(bytes32 id) external onlyAdmin {
        require(operations[id].eta != 0, "Timelock::cancel: Operation hasn't been scheduled");
        require(!operations[id].executed, "Timelock::cancel: Operation has already been executed");

        delete operations[id];
        emit OperationCancelled(id);
    }
}