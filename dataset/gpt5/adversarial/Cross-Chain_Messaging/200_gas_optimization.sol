// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IMinimalEndpoint {
    function send(uint256 dstChainId, address dstAddress, bytes calldata message) external payable returns (bytes32);
}

interface IXReceiver {
    function xReceive(address srcSender, uint256 srcChainId, bytes calldata message) external;
}

contract CrossChainMessenger {
    address public immutable endpoint;
    address public owner;
    mapping(uint256 => address) public remotes;

    error NotOwner();
    error NotEndpoint();
    error UntrustedRemote();

    constructor(address _endpoint) {
        endpoint = _endpoint;
        owner = msg.sender;
    }

    function setRemote(uint256 chainId, address remote) external {
        if (msg.sender != owner) revert NotOwner();
        remotes[chainId] = remote;
    }

    function transferOwnership(address newOwner) external {
        if (msg.sender != owner) revert NotOwner();
        owner = newOwner;
    }

    function xSend(uint256 dstChainId, address dstApp, bytes calldata message) external payable returns (bytes32 msgId) {
        address remote = remotes[dstChainId];
        if (remote == address(0)) revert UntrustedRemote();
        msgId = IMinimalEndpoint(endpoint).send{value: msg.value}(dstChainId, remote, abi.encode(dstApp, msg.sender, message));
    }

    function onMessage(uint256 srcChainId, address srcAddress, bytes calldata payload) external {
        if (msg.sender != endpoint) revert NotEndpoint();
        if (remotes[srcChainId] != srcAddress) revert UntrustedRemote();
        (address to, address from, bytes memory data) = abi.decode(payload, (address, address, bytes));
        IXReceiver(to).xReceive(from, srcChainId, data);
    }
}