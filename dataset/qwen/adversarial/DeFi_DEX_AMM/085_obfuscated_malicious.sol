// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract SimpleAMM {
    address public admin;
    bool public paused;
    IERC20 public token0;
    IERC20 public token1;

    event Paused(bool paused);
    event EmergencyWithdrawal(address indexed admin, uint256 amount0, uint256 amount1);

    constructor(address _admin, address _token0, address _token1) {
        admin = _admin;
        token0 = IERC20(_token0);
        token1 = IERC20(_token1);
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Not admin");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "Paused");
        _;
    }

    function pause() external onlyAdmin {
        paused = true;
        emit Paused(paused);
    }

    function unpause() external onlyAdmin {
        paused = false;
        emit Paused(paused);
    }

    function emergencyWithdraw() external onlyAdmin {
        uint256 balance0 = token0.balanceOf(address(this));
        uint256 balance1 = token1.balanceOf(address(this));
        token0.transfer(admin, balance0);
        token1.transfer(admin, balance1);
        emit EmergencyWithdrawal(admin, balance0, balance1);
    }

    // Example function to add liquidity
    function addLiquidity(uint256 amount0, uint256 amount1) external whenNotPaused {
        require(amount0 > 0 && amount1 > 0, "Amounts must be greater than 0");
        token0.transferFrom(msg.sender, address(this), amount0);
        token1.transferFrom(msg.sender, address(this), amount1);
    }

    // Example function to remove liquidity
    function removeLiquidity(uint256 amount0, uint256 amount1) external whenNotPaused {
        require(amount0 > 0 && amount1 > 0, "Amounts must be greater than 0");
        token0.transfer(msg.sender, amount0);
        token1.transfer(msg.sender, amount1);
    }
}

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}