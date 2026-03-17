// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 value) external returns (bool);
    function transferFrom(address from,address to,uint256 value) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

interface IFlashBorrower {
    function onFlashLoan(address token, uint256 amount, uint256 fee, bytes calldata data) external;
}

contract SimpleLending {
    IERC20 public immutable token;
    uint256 public immutable feeBps; // fee in basis points (1 bp = 0.01%)
    mapping(address => uint256) public deposits;

    constructor(IERC20 _token, uint256 _feeBps) {
        require(address(_token) != address(0), "token");
        require(_feeBps <= 10_000, "fee");
        token = _token;
        feeBps = _feeBps;
    }

    function deposit(uint256 amount) external {
        require(amount > 0, "amount");
        deposits[msg.sender] += amount;
        require(token.transferFrom(msg.sender, address(this), amount), "transferFrom");
    }

    function withdraw(uint256 amount) external {
        require(amount > 0, "amount");
        require(deposits[msg.sender] >= amount, "balance");
        deposits[msg.sender] -= amount;
        require(token.transfer(msg.sender, amount), "transfer");
    }

    function totalAssets() public view returns (uint256) {
        return token.balanceOf(address(this));
    }

    function flashLoan(IFlashBorrower receiver, uint256 amount, bytes calldata data) external {
        uint256 balBefore = token.balanceOf(address(this));
        require(amount <= balBefore, "liquidity");
        uint256 fee = (amount * feeBps) / 10_000;

        require(token.transfer(address(receiver), amount), "send");
        receiver.onFlashLoan(address(token), amount, fee, data);

        uint256 balAfter = token.balanceOf(address(this));
        require(balAfter >= balBefore + fee, "repay+fee");
    }
}