// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract BridgeRelayer is Ownable, ReentrancyGuard {
    using ECDSA for bytes32;
    using EnumerableSet for EnumerableSet.Bytes32Set;

    uint256 public fee;
    address public immutable target;
    address public immutable relayer;
    mapping(bytes32 => bool) public processedMessages;

    event FeeCollected(uint256 amount);
    event MessageRelay(address indexed sender, bytes32 indexed messageHash);
    event RelayerChanged(address indexed newRelayer);

    constructor(address _target, address _relayer, uint256 _fee) {
        require(_target != address(0), "Target address cannot be zero");
        require(_relayer != address(0), "Relayer address cannot be zero");
        target = _target;
        relayer = _relayer;
        fee = _fee;
    }

    function setRelayer(address newRelayer) external onlyOwner {
        require(newRelayer != address(0), "New relayer address cannot be zero");
        relayer = newRelayer;
        emit RelayerChanged(newRelayer);
    }

    function setFee(uint256 newFee) external onlyOwner {
        fee = newFee;
    }

    function relayMessage(bytes calldata message, bytes calldata signature) external payable {
        require(msg.value >= fee, "Insufficient fee");
        bytes32 messageHash = keccak256(message);
        require(!processedMessages[messageHash], "Message already processed");
        require(relayer == _verifySignature(messageHash, signature), "Invalid signature");

        processedMessages[messageHash] = true;
        (bool success, ) = target.call{value: msg.value - fee}(abi.encodePacked(message));
        require(success, "Target call failed");

        emit MessageRelay(msg.sender, messageHash);
    }

    function collectFee() external onlyOwner {
        uint256 amount = address(this).balance;
        require(amount > 0, "No fee to collect");
        payable(owner()).transfer(amount);
        emit FeeCollected(amount);
    }

    function _verifySignature(bytes32 messageHash, bytes memory signature) internal pure returns (address) {
        return messageHash.toEthSignedMessageHash().recover(signature);
    }
}