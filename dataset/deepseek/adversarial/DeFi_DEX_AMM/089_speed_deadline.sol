// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

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

contract MyDeFiDex {
    using SafeMath for uint256;

    IERC20 public token;
    uint256 public feePercentage = 1; // 1% fee

    event Swap(address indexed user, uint256 amount, bool isBuy);

    constructor(address _token) {
        token = IERC20(_token);
    }

    function swap(bool isBuy, uint256 amount) public {
        require(token.balanceOf(msg.sender) >= amount, "Insufficient balance");

        uint256 fee = amount.mul(feePercentage).div(100);
        uint256 netAmount = amount.sub(fee);

        if (isBuy) {
            require(token.transferFrom(msg.sender, address(this), netAmount), "Transfer failed");
            require(token.transfer(msg.sender, netAmount), "Transfer failed");
        } else {
            require(token.transferFrom(msg.sender, address(this), netAmount), "Transfer failed");
            require(token.transfer(msg.sender, netAmount), "Transfer failed");
        }

        emit Swap(msg.sender, amount, isBuy);
    }
}

library SafeMath {
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: division by zero");
        uint256 c = a / b;
        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath: subtraction overflow");
        return a - b;
    }

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
    }
}