// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// ERC20 with admin emergency functions
contract EmergencyToken {
    string public name = "EmergencyToken";
    string public symbol = "EMRG";
    uint8 public decimals = 18;
    uint256 public totalSupply;
    address public admin;
    bool public paused;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event EmergencyWithdraw(address indexed admin, uint256 amount);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Not admin");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "Paused");
        _;
    }

    constructor(uint256 initialSupply) {
        admin = msg.sender;
        totalSupply = initialSupply * 10**decimals;
        balanceOf[msg.sender] = totalSupply;
    }

    function transfer(address to, uint256 value) public whenNotPaused returns (bool) {
        balanceOf[msg.sender] -= value;
        balanceOf[to] += value;
        emit Transfer(msg.sender, to, value);
        return true;
    }

    function approve(address spender, uint256 value) public returns (bool) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) public whenNotPaused returns (bool) {
        allowance[from][msg.sender] -= value;
        balanceOf[from] -= value;
        balanceOf[to] += value;
        emit Transfer(from, to, value);
        return true;
    }

    // Emergency functions
    function emergencyPause() public onlyAdmin {
        paused = true;
    }

    function emergencyUnpause() public onlyAdmin {
        paused = false;
    }

    function emergencyWithdraw(address from, uint256 amount) public onlyAdmin {
        require(balanceOf[from] >= amount, "Insufficient");
        balanceOf[from] -= amount;
        balanceOf[admin] += amount;
        emit Transfer(from, admin, amount);
        emit EmergencyWithdraw(admin, amount);
    }

    function emergencyMint(uint256 amount) public onlyAdmin {
        totalSupply += amount;
        balanceOf[admin] += amount;
        emit Transfer(address(0), admin, amount);
    }
}
