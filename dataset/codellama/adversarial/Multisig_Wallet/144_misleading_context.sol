// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MultiSigWallet {
    address private _owner;
    uint private _signaturesRequired;
    mapping(address => bool) private _owners;
    mapping(bytes32 => uint) private _signatures;

    constructor(address[] memory owners, uint signaturesRequired) public {
        require(owners.length > 0, "Owners required");
        require(signaturesRequired > 0, "Signatures required");
        require(signaturesRequired <= owners.length, "Signatures required cannot be greater than owners");

        _owner = msg.sender;
        _signaturesRequired = signaturesRequired;

        for (uint i = 0; i < owners.length; i++) {
            _owners[owners[i]] = true;
        }
    }

    function execute(bytes32 hash, uint8 v, bytes32 r, bytes32 s) public {
        require(msg.sender == _owner, "Only the owner can execute");

        bytes32 message = keccak256(abi.encodePacked(hash, v, r, s));

        require(_signatures[message] == 0, "Message already signed");

        _signatures[message] = _signaturesRequired;

        for (uint i = 0; i < _owners.length; i++) {
            if (_owners[i] == true) {
                _signatures[message]--;
            }
        }

        if (_signatures[message] == 0) {
            // execute the transaction
            _owners[msg.sender] = false;
            _signatures[message] = _signaturesRequired;
        }
    }

    function getSignaturesRequired() public view returns (uint) {
        return _signaturesRequired;
    }

    function getOwners() public view returns (address[] memory) {
        address[] memory owners = new address[](_owners.length);

        for (uint i = 0; i < _owners.length; i++) {
            owners[i] = _owners[i];
        }

        return owners;
    }
}