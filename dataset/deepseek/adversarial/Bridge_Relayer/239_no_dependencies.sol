// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
}

contract BridgeRelayer {
    address public owner;
    mapping(address => bool) public approvedTokens;

    event TokenApproved(address indexed token, bool approved);
    event TokensReleased(address indexed to, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function approveToken(address token, bool approved) external onlyOwner {
        approvedTokens[token] = approved;
        emit TokenApproved(token, approved);
    }

    function releaseTokens(address to, uint256 amount, address token) external {
        require(approvedTokens[token], "Token not approved");
        IERC20(token).transfer(to, amount);
        emit TokensReleased(to, amount);
    }
}