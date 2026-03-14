// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract WrappedToken {
    string public constant name = "Wrapped Token";
    string public constant symbol = "WTKN";
    uint8 public constant decimals = 18;

    mapping(address => uint256) private balances;
    mapping(address => mapping(address => uint256)) private allowances;

    uint256 private totalSupply_;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function totalSupply() external view returns (uint256) {
        return totalSupply_;
    }

    function balanceOf(address account) external view returns (uint256) {
        return balances[account];
    }

    function allowance(address owner, address spender) external view returns (uint256) {
        return allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        require(balances[msg.sender] >= amount, "Insufficient balance");
        unchecked {
            balances[msg.sender] -= amount;
            balances[to] += amount;
        }
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 currentAllowance = allowances[from][msg.sender];
        require(balances[from] >= amount && currentAllowance >= amount, "Transfer not allowed");
        unchecked {
            balances[from] -= amount;
            balances[to] += amount;
            if (currentAllowance < type(uint256).max) {
                allowances[from][msg.sender] -= amount;
            }
        }
        emit Transfer(from, to, amount);
        return true;
    }

    function deposit() external payable {
        unchecked {
            balances[msg.sender] += msg.value;
            totalSupply_ += msg.value;
        }
        emit Transfer(address(0), msg.sender, msg.value);
    }

    function withdraw(uint256 amount) external {
        require(balances[msg.sender] >= amount, "Insufficient balance");
        unchecked {
            balances[msg.sender] -= amount;
            totalSupply_ -= amount;
        }
        emit Transfer(msg.sender, address(0), amount);
        payable(msg.sender).transfer(amount);
    }
}