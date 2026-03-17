// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MultisigWallet {
    address[] public owners;
    mapping(address => bool) public isOwner;
    uint256 public required;

    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint256 numConfirmations;
    }

    Transaction[] public transactions;
    mapping(uint256 => mapping(address => bool)) public confirmed;

    constructor(address[] memory _owners, uint256 _required) {
        require(_owners.length > 0, "owners required");
        require(_required > 0 && _required <= _owners.length, "invalid required");

        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "invalid owner");
            require(!isOwner[owner], "owner not unique");
            isOwner[owner] = true;
            owners.push(owner);
        }

        required = _required;
    }

    receive() external payable {}

    function submit(address to, uint256 value, bytes memory data) external {
        require(isOwner[msg.sender], "not owner");
        transactions.push(Transaction({to: to, value: value, data: data, executed: false, numConfirmations: 0}));
    }

    function confirm(uint256 txId) external {
        require(isOwner[msg.sender], "not owner");
        require(txId < transactions.length, "tx does not exist");
        Transaction storage t = transactions[txId];
        require(!t.executed, "already executed");
        require(!confirmed[txId][msg.sender], "already confirmed");

        confirmed[txId][msg.sender] = true;
        t.numConfirmations += 1;

        if (t.numConfirmations >= required) {
            t.executed = true;
            (bool ok, ) = t.to.call{value: t.value}(t.data);
            require(ok, "tx failed");
        }
    }
}