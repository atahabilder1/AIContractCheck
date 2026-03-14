// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract BridgeRelayer {
    address private _owner;

    constructor() public {
        _owner = msg.sender;
    }

    function relay(address recipient, uint256 amount) public {
        require(msg.sender == _owner, "Only the owner can call this function");
        require(recipient != address(0), "Invalid recipient");
        require(amount > 0, "Invalid amount");

        payable(recipient).transfer(amount);
    }
}