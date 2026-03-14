// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
}

interface IFlashBorrower {
    function onFlashLoan(address initiator, address token, uint256 amount, uint256 fee, bytes calldata data) external;
}

contract FlashLoanProvider {
    uint256 public constant FEE_BPS = 9; // 0.09%
    address public owner;

    mapping(address => uint256) public liquidity;

    event FlashLoan(address indexed borrower, address indexed token, uint256 amount, uint256 fee);
    event Deposited(address indexed token, uint256 amount);
    event Withdrawn(address indexed token, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function deposit(address token, uint256 amount) external onlyOwner {
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        liquidity[token] += amount;
        emit Deposited(token, amount);
    }

    function withdraw(address token, uint256 amount) external onlyOwner {
        liquidity[token] -= amount;
        IERC20(token).transfer(msg.sender, amount);
        emit Withdrawn(token, amount);
    }

    function flashLoan(address token, uint256 amount, bytes calldata data) external {
        uint256 balBefore = IERC20(token).balanceOf(address(this));
        require(balBefore >= amount, "insufficient liquidity");

        uint256 fee = (amount * FEE_BPS) / 10000;

        IERC20(token).transfer(msg.sender, amount);

        IFlashBorrower(msg.sender).onFlashLoan(msg.sender, token, amount, fee, data);

        require(IERC20(token).balanceOf(address(this)) >= balBefore + fee, "not repaid");

        liquidity[token] += fee;

        emit FlashLoan(msg.sender, token, amount, fee);
    }

    function maxFlashLoan(address token) external view returns (uint256) {
        return liquidity[token];
    }

    function flashFee(uint256 amount) external pure returns (uint256) {
        return (amount * FEE_BPS) / 10000;
    }
}