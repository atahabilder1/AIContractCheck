// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Timelock {
    error NotAdmin();
    error AlreadyQueued();
    error NotReady();

    address public immutable admin;
    uint48 public immutable delay;

    mapping(bytes32 => uint48) public readyAt;

    constructor(uint48 _delay, address _admin) {
        admin = _admin;
        delay = _delay;
    }

    function queue(address target, uint256 value, bytes calldata data) external returns (bytes32 id) {
        if (msg.sender != admin) revert NotAdmin();
        id = keccak256(abi.encode(target, value, data));
        if (readyAt[id] != 0) revert AlreadyQueued();
        unchecked {
            readyAt[id] = uint48(block.timestamp) + delay;
        }
    }

    function cancel(bytes32 id) external {
        if (msg.sender != admin) revert NotAdmin();
        delete readyAt[id];
    }

    function execute(address target, uint256 value, bytes calldata data) external payable returns (bytes memory result) {
        bytes32 id = keccak256(abi.encode(target, value, data));
        uint48 t = readyAt[id];
        if (t == 0 || block.timestamp < t) revert NotReady();
        delete readyAt[id];

        (bool ok, bytes memory r) = target.call{value: value}(data);
        if (!ok) assembly {
            revert(add(r, 0x20), mload(r))
        }
        return r;
    }

    receive() external payable {}
}