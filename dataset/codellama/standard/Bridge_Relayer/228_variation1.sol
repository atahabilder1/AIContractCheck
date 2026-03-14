// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Relayer {
    address[] public relayers;
    mapping(address => bool) public isRelayer;

    constructor(address[] memory _relayers) {
        relayers = _relayers;
        for (uint256 i = 0; i < relayers.length; i++) {
            isRelayer[relayers[i]] = true;
        }
    }

    function submitMessage(string memory _message) public {
        require(isRelayer[msg.sender], "Only relayers can submit messages");
        // store message in a mapping
    }

    function validateMessage(string memory _message) public view returns (bool) {
        for (uint256 i = 0; i < relayers.length; i++) {
            if (keccak256(abi.encodePacked(_message)) != keccak256(abi.encodePacked(relayers[i]))) {
                return false;
            }
        }
        return true;
    }
}