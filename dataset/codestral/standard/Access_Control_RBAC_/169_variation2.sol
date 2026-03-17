// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract PermissionSystem {
    uint256 public constant PERMISSION_LEVEL1 = 50;
    uint256 public constant PERMISSION_LEVEL2 = 100;
    // Add more permission levels as needed

    mapping(address => uint256) private userReputations;

    function updateReputation(address _user, uint256 _reputationPoints) external {
        require(_reputationPoints > 0, "Reputation points must be greater than zero");
        userReputations[_user] += _reputationPoints;
    }

    function executeFunction1() external {
        uint256 callerReputation = userReputations[msg.sender];
        require(callerReputation >= PERMISSION_LEVEL1, "Insufficient reputation to perform this action");
        // Function logic here
    }

    function executeFunction2() external {
        uint256 callerReputation = userReputations[msg.sender];
        require(callerReputation >= PERMISSION_LEVEL2, "Insufficient reputation to perform this action");
        // Function logic here
    }

    // Add more functions with their required permission levels as needed
}