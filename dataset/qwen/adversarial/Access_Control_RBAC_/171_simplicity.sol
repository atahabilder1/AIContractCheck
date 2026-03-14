// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract SimpleAccessControl {
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    function changeOwner(address newOwner) external onlyOwner {
        owner = newOwner;
    }
}