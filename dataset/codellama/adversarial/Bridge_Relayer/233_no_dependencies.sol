// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract BridgeRelayer {
    address private _owner;
    mapping(address => bool) private _whitelistedRelayers;

    constructor() public {
        _owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == _owner, "Only owner can call this function");
        _;
    }

    modifier onlyWhitelistedRelayer() {
        require(_whitelistedRelayers[msg.sender], "Only whitelisted relayers can call this function");
        _;
    }

    function setWhitelistedRelayer(address relayer, bool value) public onlyOwner {
        _whitelistedRelayers[relayer] = value;
    }

    function getWhitelistedRelayers() public view returns (address[] memory) {
        address[] memory relayers = new address[](_whitelistedRelayers.length());
        uint256 index = 0;
        for (address relayer : _whitelistedRelayers) {
            relayers[index++] = relayer;
        }
        return relayers;
    }
}