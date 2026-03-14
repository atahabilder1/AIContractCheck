// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ILayerZeroReceiver {
    function lzReceive(uint16 _srcChainId, bytes memory _srcAddress, uint64 _nonce, bytes memory _payload) external;
}

interface ILayerZeroEndpoint {
    function sendMessage(uint16 _dstChainId, bytes memory _payload, address payable _refundAddress, address _zroPaymentAddress, bytes memory _adapterParams) external payable;
}

contract CrossChainMessenger {
    ILayerZeroEndpoint public endpoint;
    mapping(uint16 => mapping(bytes => uint64)) public nonces;
    mapping(uint16 => mapping(bytes => uint256)) public retryCounts;
    uint256 public retryDelay;
    uint256 public maxRetryCount;

    event MessageSent(uint16 indexed dstChainId, bytes indexed dstAddress, uint64 nonce, bytes payload);
    event MessageReceived(uint16 indexed srcChainId, bytes indexed srcAddress, uint64 nonce, bytes payload);

    constructor(address _endpoint, uint256 _retryDelay, uint256 _maxRetryCount) {
        endpoint = ILayerZeroEndpoint(_endpoint);
        retryDelay = _retryDelay;
        maxRetryCount = _maxRetryCount;
    }

    function sendMessage(uint16 _dstChainId, bytes memory _dstAddress, bytes memory _payload) public payable {
        require(msg.value > 0, "Insufficient fee");
        uint64 nonce = nonces[_dstChainId][_dstAddress];
        endpoint.sendMessage{value: msg.value}(_dstChainId, _payload, payable(address(this)), address(this), "");
        nonces[_dstChainId][_dstAddress] = nonce + 1;
        emit MessageSent(_dstChainId, _dstAddress, nonce, _payload);
    }

    function lzReceive(uint16 _srcChainId, bytes memory _srcAddress, uint64 _nonce, bytes memory _payload) external {
        require(msg.sender == address(endpoint), "Only endpoint can call this function");
        if (retryCounts[_srcChainId][_srcAddress] < maxRetryCount) {
            retryCounts[_srcChainId][_srcAddress]++;
            endpoint.sendMessage{value: msg.value}(_srcChainId, _payload, payable(address(this)), address(this), "");
        } else {
            emit MessageReceived(_srcChainId, _srcAddress, _nonce, _payload);
        }
    }
}