// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract QuadraticVotingDAO is Ownable {
    using SafeMath for uint256;

    IERC20 public token;
    mapping(address => uint256) private _votes;

    constructor(IERC20 _token) {
        token = _token;
    }

    function vote(uint256 proposalId, uint256 amount) external {
        require(_votes[msg.sender] == 0, "Already voted");
        require(amount > 0 && token.balanceOf(msg.sender) >= amount, "Invalid amount");

        _votes[msg.sender] = sqrt(amount);
        // Implementation of the voting logic for proposalId with quadratic voting power goes here
    }

    function withdrawVote(uint256 proposalId) external {
        require(_votes[msg.sender] > 0, "No vote to withdraw");

        _votes[msg.sender] = 0;
        // Implementation of the voting withdrawal logic for proposalId goes here
    }
}