// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract SimpleMultisigWallet {
    address[] public owners;
    uint public required;

    constructor(address[] memory _owners, uint _required) {
        require(_owners.length > 0 && _required > 0 && _required <= _owners.length);
        owners = _owners;
        required = _required;
    }

    function submitTransaction(address payable _to, uint _value, bytes memory _data) public {
        require(isOwner(msg.sender), "Not an owner");
        _to.call{value: _value}(_data);
    }

    function isOwner(address _address) public view returns (bool) {
        for (uint i = 0; i < owners.length; i++) {
            if (owners[i] == _address) {
                return true;
            }
        }
        return false;
    }
}