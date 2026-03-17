// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract MultiSigWallet {
    address[] public owners;
    uint requiredConfirmations;

    mapping(address => bool) public isOwner;
    mapping(uint => bool) public confirmedTransactions;

    constructor(address[] memory _owners, uint _requiredConfirmations) {
        require(_owners.length > 0, "No owners specified");
        require(_requiredConfirmations <= _owners.length, "Required confirmations exceeds owner count");

        for (uint i = 0; i < _owners.length; ++i) {
            isOwner[_owners[i]] = true;
        }

        owners = _owners;
        requiredConfirmations = _requiredConfirmations;
    }

    function submitTransaction(address to, uint256 value, bytes memory data) external returns (uint transactionId) {
        require(isOwner[msg.sender], "Sender is not an owner");
        transactionId = keccak256(abi.encodePacked(to, value, data));
    }

    function confirmTransaction(uint transactionId) external {
        require(isOwner[msg.sender], "Sender is not an owner");
        require(!confirmedTransactions[transactionId], "Transaction already confirmed");
        confirmedTransactions[transactionId] = true;

        if (getConfirmationCount(transactionId) >= requiredConfirmations) {
            bytes memory data = getTransactionData(transactionId);
            address to = extractAddressFromBytes(data, 0);
            uint256 value = extractUintFromBytes(data, 32);
            executeTransaction(to, value, data);
        }
    }

    function executeTransaction(address to, uint256 value, bytes memory data) internal {
        (bool success, ) = to.call{value: value}(data);
        require(success, "Transaction failed");
        confirmedTransactions[keccak256(abi.encodePacked(to, value, data))] = false;
    }

    function getConfirmationCount(uint transactionId) private view returns (uint count) {
        for (uint i = 0; i < owners.length; ++i) {
            if (confirmedTransactions[transactionId]) {
                count++;
            }
        }
    }

    function getTransactionData(uint transactionId) private view returns (bytes memory data) {
        assembly {
            let len := mload(0x40)
            data := malloc(len)
            for {let i := 0; i < len; i++} {
                data[i] := calldataload(add(36, i))
            }
        }
    }

    function extractAddressFromBytes(bytes memory data, uint startIndex) private pure returns (address addr) {
        assembly {
            addr := mload(add(data, add(startIndex, 12)))
        }
    }

    function extractUintFromBytes(bytes memory data, uint startIndex) private pure returns (uint value) {
        assembly {
            value := mload(add(data, startIndex))
        }
    }
}