// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract GasOptimizedBridgeRelayer {
    address public immutable bridgeAdmin;
    mapping(uint256 => bool) public processedNonces;

    event MessageProcessed(uint256 indexed nonce, address indexed sender, bytes data);

    constructor(address _bridgeAdmin) {
        bridgeAdmin = _bridgeAdmin;
    }

    modifier onlyBridgeAdmin() {
        require(msg.sender == bridgeAdmin, "Not bridge admin");
        _;
    }

    function relayMessage(uint256 nonce, address sender, bytes calldata data) external onlyBridgeAdmin {
        require(!processedNonces[nonce], "Nonce already processed");
        processedNonces[nonce] = true;
        emit MessageProcessed(nonce, sender, data);
    }
}