// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract GasOptimizedMultisigWallet {
    address private _owner;
    mapping(address => bool) private _signers;
    uint256 private _threshold;

    event Deposit(address indexed from, uint256 value);
    event Withdrawal(address indexed to, uint256 value);

    constructor(address owner, uint256 threshold) public {
        _owner = owner;
        _threshold = threshold;
    }

    function addSigner(address signer) public {
        require(msg.sender == _owner, "Only the owner can add signers");
        require(!_signers[signer], "Signer already exists");
        _signers[signer] = true;
    }

    function removeSigner(address signer) public {
        require(msg.sender == _owner, "Only the owner can remove signers");
        require(_signers[signer], "Signer does not exist");
        _signers[signer] = false;
    }

    function getSigners() public view returns (address[] memory) {
        address[] memory signers = new address[](_threshold);
        for (uint256 i = 0; i < _threshold; i++) {
            signers[i] = _signers[i];
        }
        return signers;
    }

    function deposit() public payable {
        require(msg.value > 0, "Invalid deposit amount");
        emit Deposit(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) public {
        require(amount > 0, "Invalid withdraw amount");
        require(amount <= address(this).balance, "Insufficient balance");
        emit Withdrawal(msg.sender, amount);
    }
}