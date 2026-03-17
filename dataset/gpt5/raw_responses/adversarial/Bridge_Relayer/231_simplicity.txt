// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract BridgeRelayer {
    address public immutable relayer;

    event Relayed(address indexed target, uint256 value, bytes data);

    constructor(address _relayer) {
        relayer = _relayer;
    }

    modifier onlyRelayer() {
        require(msg.sender == relayer, "not relayer");
        _;
    }

    function relay(address target, bytes calldata data) external payable onlyRelayer {
        (bool ok,) = target.call{value: msg.value}(data);
        require(ok, "call failed");
        emit Relayed(target, msg.value, data);
    }
}