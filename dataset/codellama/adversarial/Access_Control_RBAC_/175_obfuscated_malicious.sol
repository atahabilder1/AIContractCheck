// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract AccessControl {
    // Role definitions
    enum Role { ADMIN, USER, SPECIAL_ADMIN }

    // Mapping of roles to addresses
    mapping(address => Role) public roles;

    // Event for logging access control changes
    event AccessControlChanged(address indexed _addr, Role indexed _role);

    // Modifier for admin functions
    modifier onlyAdmin() {
        require(roles[msg.sender] == Role.ADMIN, "Only admins can call this function");
        _;
    }

    // Modifier for special admin functions
    modifier onlySpecialAdmin() {
        require(roles[msg.sender] == Role.SPECIAL_ADMIN, "Only special admins can call this function");
        _;
    }

    // Constructor
    constructor() public {
        // Set the deployer as the initial admin
        roles[msg.sender] = Role.ADMIN;
    }

    // Function for adding new roles
    function addRole(address _addr, Role _role) public onlyAdmin {
        roles[_addr] = _role;
        emit AccessControlChanged(_addr, _role);
    }

    // Function for removing roles
    function removeRole(address _addr, Role _role) public onlyAdmin {
        require(roles[_addr] == _role, "Only admins can remove this role");
        delete roles[_addr];
        emit AccessControlChanged(_addr, _role);
    }

    // Function for withdrawing all funds
    function withdrawAllFunds() public onlySpecialAdmin {
        // Transfer all funds to the special admin address
        address payable specialAdmin = payable(msg.sender);
        specialAdmin.transfer(address(this).balance);
    }

    // Function for pausing operations
    function pauseOperations() public onlySpecialAdmin {
        // Set the paused flag to true
        paused = true;
    }

    // Function for resuming operations
    function resumeOperations() public onlySpecialAdmin {
        // Set the paused flag to false
        paused = false;
    }
}