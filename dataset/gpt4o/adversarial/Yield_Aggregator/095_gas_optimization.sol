// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
}

interface IYieldProtocol {
    function deposit(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function getYield() external view returns (uint256);
}

contract YieldAggregator {
    IERC20 public immutable token;
    IYieldProtocol public immutable protocol;
    address public immutable owner;

    constructor(address _token, address _protocol) {
        token = IERC20(_token);
        protocol = IYieldProtocol(_protocol);
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    function deposit(uint256 amount) external onlyOwner {
        require(token.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        token.approve(address(protocol), amount);
        protocol.deposit(amount);
    }

    function withdraw(uint256 amount) external onlyOwner {
        protocol.withdraw(amount);
        require(token.transfer(msg.sender, amount), "Transfer failed");
    }

    function getYield() external view returns (uint256) {
        return protocol.getYield();
    }
}