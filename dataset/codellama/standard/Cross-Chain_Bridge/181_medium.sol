// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CrossChainBridge {
    address private _owner;
    mapping(address => uint256) private _nonce;
    mapping(address => bool) private _whitelistedRelayers;

    event Transfer(address indexed from, address indexed to, uint256 amount);

    constructor() {
        _owner = msg.sender;
    }

    function transfer(address to, uint256 amount) external {
        require(msg.sender == _owner, "Only the owner can transfer");
        require(amount > 0, "Invalid amount");
        require(_nonce[msg.sender] == 0, "Invalid nonce");
        require(_whitelistedRelayers[msg.sender], "Relayer not whitelisted");

        _nonce[msg.sender] = amount;
        emit Transfer(msg.sender, to, amount);
    }

    function whitelistRelayer(address relayer) external {
        require(msg.sender == _owner, "Only the owner can whitelist");
        require(relayer != address(0), "Invalid relayer");

        _whitelistedRelayers[relayer] = true;
    }

    function getNonce(address account) external view returns (uint256) {
        return _nonce[account];
    }

    function getWhitelistedRelayers() external view returns (address[] memory) {
        return _whitelistedRelayers;
    }
}