// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IToken {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

contract CrossChainBridge {
    address public owner;
    IToken public token;
    address public validator;

    event TokensLocked(address indexed user, uint256 amount, uint256 targetChainId, address targetAddress);
    event TokensUnlocked(address indexed user, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    modifier onlyValidator() {
        require(msg.sender == validator, "Not the validator");
        _;
    }

    constructor(address _token, address _validator) {
        owner = msg.sender;
        token = IToken(_token);
        validator = _validator;
    }

    function setValidator(address _validator) external onlyOwner {
        validator = _validator;
    }

    function lockTokens(uint256 amount, uint256 targetChainId, address targetAddress) external {
        require(amount > 0, "Amount must be greater than zero");
        require(token.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        emit TokensLocked(msg.sender, amount, targetChainId, targetAddress);
    }

    function unlockTokens(address user, uint256 amount) external onlyValidator {
        require(amount > 0, "Amount must be greater than zero");
        require(token.balanceOf(address(this)) >= amount, "Insufficient contract balance");
        require(token.transfer(user, amount), "Transfer failed");
        emit TokensUnlocked(user, amount);
    }
}