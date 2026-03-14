// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract TimelockController is Context, AccessControl {
    using Address for address payable;
    using EnumerableSet for EnumerableSet.bytes32Set;

    bytes32 public constant TIMELOCK_ADMIN_ROLE = keccak256("TIMELOCK_ADMIN_ROLE");
    bytes32 public constant PROPOSER_ROLE = keccak256("PROPOSER_ROLE");
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");
    bytes32 public constant CANCELLER_ROLE = keccak256("CANCELLER_ROLE");

    uint256 private _minDelay;
    mapping(bytes32 => bool) private _isOperation;
    mapping(bytes32 => bool) private _isOperationDone;
    mapping(bytes32 => uint256) private _timestamps;
    mapping(bytes32 => bytes32) private _predecessors;

    event CallScheduled(
        bytes32 indexed id,
        uint256 indexed index,
        address target,
        uint256 value,
        bytes data,
        bytes32 predecessor,
        uint256 delay
    );
    event CallExecuted(bytes32 indexed id, uint256 indexed index, address target, uint256 value, bytes data);
    event OperationCancelled(bytes32 indexed id);
    event MinDelayChangeRequested(uint256 oldDuration, uint256 newDuration);
    event MinDelayChanged(uint256 oldDuration, uint256 newDuration);

    constructor(
        uint256 minDelay,
        address[] memory proposers,
        address[] memory executors,
        address admin
    ) {
        _setRoleAdmin(TIMELOCK_ADMIN_ROLE, TIMELOCK_ADMIN_ROLE);
        _setRoleAdmin(PROPOSER_ROLE, TIMELOCK_ADMIN_ROLE);
        _setRoleAdmin(EXECUTOR_ROLE, TIMELOCK_ADMIN_ROLE);
        _setRoleAdmin(CANCELLER_ROLE, TIMELOCK_ADMIN_ROLE);

        // deployer + self administration
        _setupRole(TIMELOCK_ADMIN_ROLE, _msgSender());
        _setupRole(TIMELOCK_ADMIN_ROLE, address(this));

        for (uint256 i = 0; i < proposers.length; ++i) {
            _setupRole(PROPOSER_ROLE, proposers[i]);
        }

        for (uint256 i = 0; i < executors.length; ++i) {
            _setupRole(EXECUTOR_ROLE, executors[i]);
        }

        _setRoleAdmin(TIMELOCK_ADMIN_ROLE, admin);

        _minDelay = minDelay;
        emit MinDelayChanged(0, minDelay);
    }

    function isOperation(bytes32 id) public view virtual returns (bool registered) {
        registered = _isOperation[id];
    }

    function isOperationPending(bytes32 id) public view virtual returns (bool pending) {
        return _isOperation[id] && !_isOperationDone[id] && block.timestamp < _timestamps[id];
    }

    function isOperationReady(bytes32 id) public view virtual returns (bool ready) {
        return _isOperation[id] && !_isOperationDone[id] && block.timestamp >= _timestamps[id];
    }

    function isOperationDone(bytes32 id) public view virtual returns (bool done) {
        done = _isOperationDone[id];
    }

    function getMinDelay() public view virtual returns (uint256 duration) {
        duration = _minDelay;
    }

    function hashOperation(
        address target,
        uint256 value,
        bytes calldata data,
        bytes32 predecessor,
        bytes32 salt
    ) public pure virtual returns (bytes32 hash) {
        hash = keccak256(abi.encode(target, value, data, predecessor, salt));
    }

    function hashOperationBatch(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata datas,
        bytes32 predecessor,
        bytes32 salt
    ) public pure virtual returns (bytes32 hash) {
        require(targets.length == values.length, "TimelockController: length mismatch");
        require(targets.length == datas.length, "TimelockController: length mismatch");

        bytes32[] memory hashes = new bytes32[](targets.length);
        for (uint256 i = 0; i < targets.length; ++i) {
            hashes[i] = hashOperation(targets[i], values[i], datas[i], 0, salt);
        }
        hash = keccak256(abi.encode(hashes, predecessor, salt));
    }

    function schedule(
        address target,
        uint256 value,
        bytes calldata data,
        bytes32 predecessor,
        bytes32 salt,
        uint256 delay
    ) public virtual onlyRole(PROPOSER_ROLE) {
        bytes32 id = hashOperation(target, value, data, predecessor, salt);
        _schedule(id, delay);
        emit CallScheduled(id, 0, target, value, data, predecessor, delay);
    }

    function scheduleBatch(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata datas,
        bytes32 predecessor,
        bytes32 salt,
        uint256 delay
    ) public virtual onlyRole(PROPOSER_ROLE) {
        require(targets.length == values.length, "TimelockController: length mismatch");
        require(targets.length == datas.length, "TimelockController: length mismatch");

        bytes32 id = hashOperationBatch(targets, values, datas, predecessor, salt);
        _schedule(id, delay);
        for (uint256 i = 0; i < targets.length; ++i) {
            emit CallScheduled(id, i, targets[i], values[i], datas[i], predecessor, delay);
        }
    }

    function cancel(bytes32 id) public virtual onlyRole(CANCELLER_ROLE) {
        require(isOperationPending(id), "TimelockController: operation cannot be cancelled");
        delete _timestamps[id];
        delete _predecessors[id];
        _isOperation[id] = false;
        emit OperationCancelled(id);
    }

    function execute(
        address target,
        uint256 value,
        bytes calldata data,
        bytes32 predecessor,
        bytes32 salt
    ) public payable virtual onlyRoleOrOpenRole(EXECUTOR_ROLE) {
        bytes32 id = hashOperation(target, value, data, predecessor, salt);
        _beforeCall(id, predecessor);
        _call(target, value, data);
        _afterCall(id);
    }

    function executeBatch(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata datas,
        bytes32 predecessor,
        bytes32 salt
    ) public payable virtual onlyRoleOrOpenRole(EXECUTOR_ROLE) {
        require(targets.length == values.length, "TimelockController: length mismatch");
        require(targets.length == datas.length, "TimelockController: length mismatch");

        bytes32 id = hashOperationBatch(targets, values, datas, predecessor, salt);
        _beforeCall(id, predecessor);
        for (uint256 i = 0; i < targets.length; ++i) {
            _call(targets[i], values[i], datas[i]);
        }
        _afterCall(id);
    }

    function updateDelay(uint256 newDelay) external virtual onlyRole(TIMELOCK_ADMIN_ROLE) {
        emit MinDelayChangeRequested(_minDelay, newDelay);
        bytes32 id = hashOperation(address(this), 0, abi.encodeCall(this.updateDelay, (newDelay)), 0, 0);
        _schedule(id, _minDelay);
    }

    function _schedule(bytes32 id, uint256 delay) private {
        require(!isOperation(id), "TimelockController: operation already scheduled");
        require(delay >= _minDelay, "TimelockController: insufficient delay");
        _timestamps[id] = block.timestamp + delay;
        _isOperation[id] = true;
    }

    function _beforeCall(bytes32 id, bytes32 predecessor) private view {
        require(isOperationReady(id), "TimelockController: operation is not ready");
        if (predecessor != 0 && bytes32(0) == _predecessors[id]) {
            _predecessors[id] = predecessor;
        }
        require(_predecessors[id] == 0 || isOperationDone(_predecessors[id]), "TimelockController: missing dependency");
    }

    function _afterCall(bytes32 id) private {
        require(isOperationReady(id), "TimelockController: operation is not ready");
        _isOperationDone[id] = true;
        emit CallExecuted(id, 0, address(0), 0, bytes(""));
    }

    function _call(address target, uint256 value, bytes memory data) private {
        require(isContract(target), "TimelockController: target must be a contract");

        (bool success, bytes memory returndata) = target.call{value: value}(data);
        Address.verifyCallResult(success, returndata, "TimelockController: low-level call failed");
    }

    modifier onlyRoleOrOpenRole(bytes32 role) {
        if (!hasRole(role, _msgSender())) {
            _checkRole(PROPOSER_ROLE, _msgSender());
        }
        _;
    }
}