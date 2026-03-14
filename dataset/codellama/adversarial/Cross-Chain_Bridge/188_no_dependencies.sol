// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CrossChainBridge {
    struct Bridge {
        address source;
        address destination;
        uint256 tokenId;
        uint256 amount;
    }

    event BridgeCreated(address indexed source, address indexed destination, uint256 tokenId, uint256 amount);

    mapping(address => mapping(uint256 => Bridge)) public bridges;

    function createBridge(address source, address destination, uint256 tokenId, uint256 amount) public {
        require(amount > 0, "Invalid amount");
        require(source != address(0), "Invalid source address");
        require(destination != address(0), "Invalid destination address");

        Bridge memory bridge = Bridge(source, destination, tokenId, amount);
        bridges[source][tokenId] = bridge;

        emit BridgeCreated(source, destination, tokenId, amount);
    }

    function getBridge(address source, uint256 tokenId) public view returns (Bridge memory) {
        return bridges[source][tokenId];
    }
}