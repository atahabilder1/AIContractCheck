// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function totalSupply() external view returns (uint);
    function balanceOf(address account) external view returns (uint);
    function transfer(address recipient, uint amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint);
    function approve(address spender, uint amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint amount) external returns (bool);
}

contract Dex {
    using SafeMath for uint;

    IERC20 public token;

    mapping(address => uint) public balances;

    event Swap(address indexed user, uint amount);

    constructor(address _token) {
        token = IERC20(_token);
    }

    function addLiquidity(uint amount) public payable {
        uint liquidity;
        if (balances[msg.sender] == 0) {
            liquidity = msg.value;
        } else {
            uint token_reserve = token.balanceOf(address(this));
            uint eth_reserve = address(this).balance - msg.value;
            liquidity = msg.value.mul(token_reserve) / eth_reserve;
        }
        balances[msg.sender] = balances[msg.sender].add(liquidity);
        token.transferFrom(msg.sender, address(this), liquidity);
    }

    function removeLiquidity(uint amount) public {
        require(balances[msg.sender] >= amount, "Insufficient balance");
        uint token_reserve = token.balanceOf(address(this));
        uint eth_amount = amount.mul(address(this).balance) / token_reserve;
        balances[msg.sender] = balances[msg.sender].sub(amount);
        token.transfer(msg.sender, amount);
        payable(msg.sender).transfer(eth_amount);
    }

    function swapTokenToEth(uint amount) public {
        require(balances[msg.sender] >= amount, "Insufficient balance");
        uint eth_received = getTokenToEthInputPrice(amount);
        balances[msg.sender] = balances[msg.sender].sub(amount);
        payable(msg.sender).transfer(eth_received);
        emit Swap(msg.sender, amount);
    }

    function swapEthToToken(uint amount) public payable {
        uint token_received = getEthToTokenInputPrice(amount);
        require(msg.value >= amount, "Insufficient ETH sent");
        balances[msg.sender] = balances[msg.sender].add(token_received);
        token.transfer(msg.sender, token_received);
        emit Swap(msg.sender, amount);
    }

    function getTokenToEthInputPrice(uint amount) public view returns (uint) {
        uint token_reserve = token.balanceOf(address(this));
        uint eth_reserve = address(this).balance;
        return amount.mul(eth_reserve) / token_reserve;
    }

    function getEthToTokenInputPrice(uint amount) public view returns (uint) {
        uint token_reserve = token.balanceOf(address(this));
        uint eth_reserve = address(this).balance;
        return amount.mul(token_reserve) / eth_reserve;
    }
}

library SafeMath {
    function mul(uint a, uint b) internal pure returns (uint) {
        if (a == 0) {
            return 0;
        }
        uint c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }

    function div(uint a, uint b) internal pure returns (uint) {
        require(b > 0, "SafeMath: division by zero");
        uint c = a / b;
        return c;
    }

    function sub(uint a, uint b) internal pure returns (uint) {
        require(b <= a, "SafeMath: subtraction overflow");
        return a - b;
    }

    function add(uint a, uint b) internal pure returns (uint) {
        uint c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
    }
}