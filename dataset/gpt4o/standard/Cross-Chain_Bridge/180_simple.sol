// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
}

contract TokenBridge {
    address public admin;
    IERC20 public token;

    event TokensLocked(address indexed user, uint256 amount, string targetChain, string targetAddress);
    event TokensUnlocked(address indexed user, uint256 amount);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Not authorized");
        _;
    }

    constructor(address _token) {
        admin = msg.sender;
        token = IERC20(_token);
    }

    function lockTokens(uint256 amount, string memory targetChain, string memory targetAddress) external {
        require(amount > 0, "Amount must be greater than zero");
        require(token.transferFrom(msg.sender, address(this), amount), "Transfer failed");

        emit TokensLocked(msg.sender, amount, targetChain, targetAddress);
    }

    function unlockTokens(address user, uint256 amount) external onlyAdmin {
        require(amount > 0, "Amount must be greater than zero");
        require(token.transfer(user, amount), "Transfer failed");

        emit TokensUnlocked(user, amount);
    }
}