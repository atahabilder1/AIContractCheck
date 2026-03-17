// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract BridgeRelayer is Ownable {
    mapping(address => bool) private _relayers;
    mapping(bytes32 => bool) private _usedMessages;
    uint256 public feePercentage;
    address payable public feeCollector;

    constructor(uint256 _feePercentage, address payable _feeCollector) {
        feePercentage = _feePercentage;
        feeCollector = _feeCollector;
    }

    function addRelayer(address _relayer) public onlyOwner {
        _relayers[_relayer] = true;
    }

    function removeRelayer(address _relayer) public onlyOwner {
        delete _relayers[_relayer];
    }

    function relayMessage(bytes memory _message, bytes memory _signature) external payable {
        require(_relayers[msg.sender], "Not an authorized relayer");
        uint256 fee = msg.value.mul(feePercentage).div(100);
        require(fee <= msg.value - fee, "Insufficient value sent for fees");

        bytes32 messageHash = keccak256(_message);
        require(!_usedMessages[messageHash], "Message already used");

        address signer = ECDSA.recover(messageHash, _signature);
        require(signer == msg.sender, "Invalid signature");

        _usedMessages[messageHash] = true;
        feeCollector.transfer(fee);

        // Process the message (e.g., emit an event or call another contract)
    }
}