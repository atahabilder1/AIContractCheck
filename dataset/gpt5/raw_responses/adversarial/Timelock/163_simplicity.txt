// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Timelock {
    address public admin;
    uint256 public immutable delay;

    mapping(bytes32 => bool) public queued;

    event Queued(bytes32 indexed txId, address indexed target, uint256 value, bytes data, uint256 eta);
    event Canceled(bytes32 indexed txId);
    event Executed(bytes32 indexed txId, address indexed target, uint256 value, bytes data, uint256 eta, bytes result);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Timelock: only admin");
        _;
    }

    constructor(address admin_, uint256 delay_) {
        require(admin_ != address(0), "Timelock: admin zero");
        require(delay_ > 0, "Timelock: delay zero");
        admin = admin_;
        delay = delay_;
    }

    function getTxId(
        address target,
        uint256 value,
        bytes calldata data,
        uint256 eta
    ) public pure returns (bytes32) {
        return keccak256(abi.encode(target, value, data, eta));
    }

    function queue(
        address target,
        uint256 value,
        bytes calldata data,
        uint256 eta
    ) external onlyAdmin returns (bytes32 txId) {
        require(eta >= block.timestamp + delay, "Timelock: eta too soon");
        txId = getTxId(target, value, data, eta);
        require(!queued[txId], "Timelock: already queued");
        queued[txId] = true;
        emit Queued(txId, target, value, data, eta);
    }

    function cancel(bytes32 txId) external onlyAdmin {
        require(queued[txId], "Timelock: not queued");
        delete queued[txId];
        emit Canceled(txId);
    }

    function execute(
        address target,
        uint256 value,
        bytes calldata data,
        uint256 eta
    ) external onlyAdmin returns (bytes memory result) {
        bytes32 txId = getTxId(target, value, data, eta);
        require(queued[txId], "Timelock: not queued");
        require(block.timestamp >= eta, "Timelock: too early");

        delete queued[txId];

        (bool ok, bytes memory res) = target.call{value: value}(data);
        require(ok, "Timelock: execution reverted");

        emit Executed(txId, target, value, data, eta, res);
        return res;
    }

    receive() external payable {}
}