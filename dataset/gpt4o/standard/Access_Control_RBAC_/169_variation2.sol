// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract PermissionSystem {
    struct User {
        uint256 reputationScore;
        mapping(bytes32 => bool) permissions;
    }

    mapping(address => User) private users;
    address private owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function setReputationScore(address user, uint256 score) external onlyOwner {
        users[user].reputationScore = score;
    }

    function addPermission(address user, bytes32 permission) external onlyOwner {
        users[user].permissions[permission] = true;
    }

    function removePermission(address user, bytes32 permission) external onlyOwner {
        users[user].permissions[permission] = false;
    }

    function hasPermission(address user, bytes32 permission) public view returns (bool) {
        return users[user].permissions[permission];
    }

    function executeLevel1Function() external {
        require(hasPermission(msg.sender, keccak256("LEVEL_1")), "Permission denied: LEVEL_1 required");
        // Function logic for level 1 permission
    }

    function executeLevel2Function() external {
        require(hasPermission(msg.sender, keccak256("LEVEL_2")), "Permission denied: LEVEL_2 required");
        // Function logic for level 2 permission
    }

    function executeLevel3Function() external {
        require(hasPermission(msg.sender, keccak256("LEVEL_3")), "Permission denied: LEVEL_3 required");
        // Function logic for level 3 permission
    }

    function getReputationScore(address user) external view returns (uint256) {
        return users[user].reputationScore;
    }
}