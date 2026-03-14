// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MinimalStaking {
    address public owner;
    mapping(address => uint256) public stakedAmounts;
    uint256 public totalStaked;

    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Caller is not the owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function stake() public payable {
        require(msg.value > 0, "Stake amount must be greater than 0");
        stakedAmounts[msg.sender] += msg.value;
        totalStaked += msg.value;
        emit Staked(msg.sender, msg.value);
    }

    function unstake(uint256 _amount) public {
        require(_amount > 0, "Unstake amount must be greater than 0");
        require(stakedAmounts[msg.sender] >= _amount, "Insufficient staked balance");

        stakedAmounts[msg.sender] -= _amount;
        totalStaked -= _amount;

        (bool success, ) = payable(msg.sender).call{value: _amount}("");
        require(success, "Transfer failed");

        emit Unstaked(msg.sender, _amount);
    }

    function getStakedAmount(address _user) public view returns (uint256) {
        return stakedAmounts[_user];
    }

    function withdrawStaked(uint256 _amount) public onlyOwner {
        require(_amount > 0, "Withdraw amount must be greater than 0");
        require(address(this).balance >= _amount, "Insufficient contract balance");

        (bool success, ) = payable(owner).call{value: _amount}("");
        require(success, "Transfer failed");
    }
}