// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract DefiStaking {
    address public stakingToken;
    mapping(address => uint) public stakedBalances;

    constructor(address _stakingToken) {
        stakingToken = _stakingToken;
    }

    function stake(uint amount) external {
        require(amount > 0, "Amount must be greater than zero");
        IERC20(stakingToken).transferFrom(msg.sender, address(this), amount);
        stakedBalances[msg.sender] += amount;
    }

    function withdraw() external {
        uint amount = stakedBalances[msg.sender];
        require(amount > 0, "No tokens to withdraw");
        IERC20(stakingToken).transfer(msg.sender, amount);
        stakedBalances[msg.sender] = 0;
    }
}

interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool success);
    function transfer(address to, uint amount) external returns (bool success);
}