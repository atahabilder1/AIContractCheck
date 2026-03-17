// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
}

interface IFlashBorrower {
    function onFlashLoan(address initiator, address token, uint256 amount, uint256 fee, bytes calldata data) external;
}

contract FlashLoanProvider {
    address public owner;
    uint256 public feeBps; // e.g., 5 = 0.05%

    event FlashLoan(address indexed receiver, address indexed token, uint256 amount, uint256 fee);
    event FeeUpdated(uint256 feeBps);
    event OwnerUpdated(address indexed owner);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor(uint256 _feeBps) {
        owner = msg.sender;
        feeBps = _feeBps;
        emit OwnerUpdated(owner);
        emit FeeUpdated(_feeBps);
    }

    function setFeeBps(uint256 _feeBps) external onlyOwner {
        feeBps = _feeBps;
        emit FeeUpdated(_feeBps);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Zero owner");
        owner = newOwner;
        emit OwnerUpdated(newOwner);
    }

    function flashLoan(IFlashBorrower receiver, IERC20 token, uint256 amount, bytes calldata data) external returns (uint256 fee) {
        require(amount > 0, "Zero amount");
        uint256 balanceBefore = token.balanceOf(address(this));
        require(balanceBefore >= amount, "Insufficient liquidity");

        fee = (amount * feeBps) / 10_000;

        require(token.transfer(address(receiver), amount), "Transfer out failed");

        receiver.onFlashLoan(msg.sender, address(token), amount, fee, data);

        uint256 balanceAfter = token.balanceOf(address(this));
        require(balanceAfter >= balanceBefore + fee, "Not repaid plus fee");

        emit FlashLoan(address(receiver), address(token), amount, fee);
    }

    function rescueTokens(IERC20 token, uint256 amount, address to) external onlyOwner {
        require(to != address(0), "Zero to");
        require(token.transfer(to, amount), "Rescue failed");
    }
}