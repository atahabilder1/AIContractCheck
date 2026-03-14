// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract RBACWithEmergency {
    // --- Roles ---
    bytes32 public constant ROLE_ADMIN = keccak256("ROLE_ADMIN");
    bytes32 public constant ROLE_MAINTAINER = keccak256("ROLE_MAINTAINER");
    bytes32 public constant ROLE_EMERGENCY_ADMIN = keccak256("ROLE_EMERGENCY_ADMIN");

    // --- Role Assignments ---
    mapping(address => mapping(bytes32 => bool)) private _roles;

    // --- Emergency State ---
    bool private _paused = false;

    // --- Events ---
    event RoleGranted(address indexed account, bytes32 indexed role);
    event RoleRevoked(address indexed account, bytes32 indexed role);
    event Paused(address indexed account);
    event Unpaused(address indexed account);
    event EmergencyWithdraw(address indexed token, address indexed to, uint256 amount);

    // --- Modifiers ---
    modifier onlyRole(bytes32 role) {
        require(_roles[msg.sender][role], "RBAC: Caller does not have the required role");
        _;
    }

    modifier whenNotPaused() {
        require(!_paused, "RBAC: Contract is paused");
        _;
    }

    modifier whenPaused() {
        require(_paused, "RBAC: Contract is not paused");
        _;
    }

    // --- Constructor ---
    constructor() {
        // Grant the deployer the EMERGENCY_ADMIN role by default
        _roles[msg.sender][ROLE_EMERGENCY_ADMIN] = true;
        emit RoleGranted(msg.sender, ROLE_EMERGENCY_ADMIN);
    }

    // --- Role Management ---
    function grantRole(address account, bytes32 role) public onlyRole(ROLE_ADMIN) {
        require(account != address(0), "RBAC: Account cannot be the zero address");
        _roles[account][role] = true;
        emit RoleGranted(account, role);
    }

    function revokeRole(address account, bytes32 role) public onlyRole(ROLE_ADMIN) {
        require(account != address(0), "RBAC: Account cannot be the zero address");
        _roles[account][role] = false;
        emit RoleRevoked(account, role);
    }

    function hasRole(address account, bytes32 role) public view returns (bool) {
        return _roles[account][role];
    }

    // --- Emergency Functions ---
    function pause() public onlyRole(ROLE_EMERGENCY_ADMIN) {
        _paused = true;
        emit Paused(msg.sender);
    }

    function unpause() public onlyRole(ROLE_EMERGENCY_ADMIN) {
        _paused = false;
        emit Unpaused(msg.sender);
    }

    function emergencyWithdraw(address tokenAddress) public onlyRole(ROLE_EMERGENCY_ADMIN) {
        require(tokenAddress != address(0), "RBAC: Token address cannot be the zero address");
        IERC20 token = IERC20(tokenAddress);
        uint256 balance = token.balanceOf(address(this));
        require(balance > 0, "RBAC: No tokens to withdraw");
        token.transfer(msg.sender, balance);
        emit EmergencyWithdraw(tokenAddress, msg.sender, balance);
    }

    // --- Fallback and Receive for Ether ---
    receive() external payable {}

    fallback() external payable {}

    // --- Utility to withdraw Ether in emergency ---
    function emergencyWithdrawEther() public onlyRole(ROLE_EMERGENCY_ADMIN) {
        uint256 balance = address(this).balance;
        require(balance > 0, "RBAC: No Ether to withdraw");
        payable(msg.sender).transfer(balance);
        emit EmergencyWithdraw(address(0), msg.sender, balance); // address(0) for Ether
    }
}

// Interface for ERC20 tokens
interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
}