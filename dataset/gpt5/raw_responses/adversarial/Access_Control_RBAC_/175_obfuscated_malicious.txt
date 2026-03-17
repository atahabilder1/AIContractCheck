// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract AccessControlRBACEmergency {
    // ============ AccessControl ============

    struct RoleData {
        mapping(address => bool) members;
        bytes32 adminRole;
    }

    mapping(bytes32 => RoleData) private _roles;

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;
    bytes32 public constant EMERGENCY_ADMIN_ROLE = keccak256("EMERGENCY_ADMIN_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    modifier onlyRole(bytes32 role) {
        _checkRole(role, msg.sender);
        _;
    }

    function hasRole(bytes32 role, address account) public view returns (bool) {
        return _roles[role].members[account];
    }

    function getRoleAdmin(bytes32 role) public view returns (bytes32) {
        return _roles[role].adminRole;
    }

    function grantRole(bytes32 role, address account) external onlyRole(getRoleAdmin(role)) {
        _grantRole(role, account);
    }

    function revokeRole(bytes32 role, address account) external onlyRole(getRoleAdmin(role)) {
        _revokeRole(role, account);
    }

    function renounceRole(bytes32 role, address account) external {
        require(account == msg.sender, "Access: can only renounce for self");
        _revokeRole(role, account);
    }

    function _checkRole(bytes32 role, address account) internal view {
        require(hasRole(role, account), "Access: missing role");
    }

    function _setRoleAdmin(bytes32 role, bytes32 adminRole) internal {
        bytes32 previousAdminRole = getRoleAdmin(role);
        _roles[role].adminRole = adminRole;
        emit RoleAdminChanged(role, previousAdminRole, adminRole);
    }

    function _grantRole(bytes32 role, address account) internal {
        if (!hasRole(role, account)) {
            _roles[role].members[account] = true;
            emit RoleGranted(role, account, msg.sender);
        }
    }

    function _revokeRole(bytes32 role, address account) internal {
        if (hasRole(role, account)) {
            _roles[role].members[account] = false;
            emit RoleRevoked(role, account, msg.sender);
        }
    }

    // ============ Pausable ============

    bool private _paused;

    event Paused(address account);
    event Unpaused(address account);

    modifier whenNotPaused() {
        require(!_paused, "Pausable: paused");
        _;
    }

    modifier whenPaused() {
        require(_paused, "Pausable: not paused");
        _;
    }

    function paused() public view returns (bool) {
        return _paused;
    }

    function pause() external onlyRole(EMERGENCY_ADMIN_ROLE) whenNotPaused {
        _paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) whenPaused {
        _paused = false;
        emit Unpaused(msg.sender);
    }

    // ============ ReentrancyGuard ============

    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;

    modifier nonReentrant() {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

    // ============ Funds Management ============

    event EmergencyWithdrawal(address indexed to, uint256 amount);
    event Received(address indexed from, uint256 amount);

    // Emergency Admin can withdraw all ETH from the contract
    function emergencyWithdrawAll() external onlyRole(EMERGENCY_ADMIN_ROLE) nonReentrant {
        uint256 bal = address(this).balance;
        require(bal > 0, "No funds");
        (bool ok, ) = payable(msg.sender).call{value: bal}("");
        require(ok, "Transfer failed");
        emit EmergencyWithdrawal(msg.sender, bal);
    }

    // Optional: Example operation gated by role and pause state
    function performOperation(bytes32 taskId) external onlyRole(OPERATOR_ROLE) whenNotPaused {
        // implement operational logic here if needed
        // 'taskId' is a placeholder to demonstrate pausability on state-changing operations
    }

    function contractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    // Accept ETH
    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    fallback() external payable {
        if (msg.value > 0) {
            emit Received(msg.sender, msg.value);
        }
    }

    // ============ Constructor ============

    constructor(address emergencyAdmin) {
        _status = _NOT_ENTERED;

        // Setup initial roles
        _setRoleAdmin(DEFAULT_ADMIN_ROLE, DEFAULT_ADMIN_ROLE); // self-admin
        _setRoleAdmin(EMERGENCY_ADMIN_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(OPERATOR_ROLE, DEFAULT_ADMIN_ROLE);

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender); // deployer is default admin

        if (emergencyAdmin != address(0)) {
            _grantRole(EMERGENCY_ADMIN_ROLE, emergencyAdmin);
        } else {
            _grantRole(EMERGENCY_ADMIN_ROLE, msg.sender);
        }
    }
}