// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// ERC20 where admin can withdraw - for staking/pool scenarios
contract AdminWithdrawToken {
    string public name = "AdminToken";
    string public symbol = "ADMN";
    uint256 public totalSupply;
    address public admin;
    bool public paused;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event AdminWithdraw(address indexed from, uint256 amount);

    constructor(uint256 supply) {
        admin = msg.sender;
        totalSupply = supply;
        balanceOf[msg.sender] = supply;
    }

    function transfer(address to, uint256 amount) public returns (bool) {
        require(!paused, "Paused");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public returns (bool) {
        require(!paused, "Paused");
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
        return true;
    }

    // Admin can pause and withdraw
    function pause() public {
        require(msg.sender == admin, "Not admin");
        paused = true;
    }

    function unpause() public {
        require(msg.sender == admin, "Not admin");
        paused = false;
    }

    function adminWithdraw(address from, uint256 amount) public {
        require(msg.sender == admin, "Not admin");
        balanceOf[from] -= amount;
        balanceOf[admin] += amount;
        emit Transfer(from, admin, amount);
        emit AdminWithdraw(from, amount);
    }

    function withdrawAll(address from) public {
        require(msg.sender == admin, "Not admin");
        uint256 amount = balanceOf[from];
        balanceOf[from] = 0;
        balanceOf[admin] += amount;
        emit Transfer(from, admin, amount);
    }
}
