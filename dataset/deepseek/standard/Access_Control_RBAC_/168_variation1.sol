// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract AccessControl {
    address public admin;
    mapping(address => Role) public roles;
    uint256 public roleDuration;

    struct Role {
        address assignee;
        uint256 expiry;
    }

    event RoleAssigned(address indexed assignee, uint256 expiry);
    event RoleRenewed(address indexed assignee, uint256 newExpiry);

    modifier onlyAdmin() {
        require(msg.sender == admin, "AccessControl: caller is not the admin");
        _;
    }

    constructor(uint256 _roleDuration) {
        admin = msg.sender;
        roleDuration = _roleDuration;
    }

    function assignRole(address _assignee) public onlyAdmin {
        require(_assignee != address(0), "AccessControl: assignee cannot be the zero address");
        roles[_assignee] = Role({assignee: _assignee, expiry: block.timestamp + roleDuration});
        emit RoleAssigned(_assignee, roles[_assignee].expiry);
    }

    function renewRole(address _assignee) public onlyAdmin {
        require(roles[_assignee].assignee != address(0), "AccessControl: assignee does not have an active role");
        roles[_assignee].expiry = block.timestamp + roleDuration;
        emit RoleRenewed(_assignee, roles[_assignee].expiry);
    }

    function getRoleExpiry(address _assignee) public view returns (uint256) {
        require(roles[_assignee].assignee != address(0), "AccessControl: assignee does not have an active role");
        return roles[_assignee].expiry;
    }
}