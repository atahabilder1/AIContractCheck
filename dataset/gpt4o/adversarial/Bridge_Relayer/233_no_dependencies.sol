// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract BridgeRelayer {
    address public owner;
    uint256 public fee;
    mapping(bytes32 => bool) public processedNonces;

    event TokensRelayed(
        address indexed from,
        address indexed to,
        uint256 amount,
        uint256 date,
        bytes32 nonce
    );

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor(uint256 _fee) {
        owner = msg.sender;
        fee = _fee;
    }

    function relayTokens(
        address to,
        uint256 amount,
        bytes32 nonce
    ) external payable {
        require(msg.value >= fee, "Insufficient fee");
        require(!processedNonces[nonce], "Transfer already processed");

        processedNonces[nonce] = true;

        // Logic to relay tokens to another chain would go here

        emit TokensRelayed(msg.sender, to, amount, block.timestamp, nonce);
    }

    function setFee(uint256 _fee) external onlyOwner {
        fee = _fee;
    }

    function withdrawFees() external onlyOwner {
        payable(owner).transfer(address(this).balance);
    }

    receive() external payable {}
}