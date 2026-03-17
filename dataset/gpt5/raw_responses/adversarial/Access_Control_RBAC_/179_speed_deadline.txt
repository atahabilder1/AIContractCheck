// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract AccessControlRBAC {
    struct RoleData {
        mapping(address => bool) members;
        bytes32 adminRole;
    }

    mapping(bytes32 => RoleData) private _roles;

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    error AccessControlUnauthorizedAccount(address account, bytes32 neededRole);

    modifier onlyRole(bytes32 role) {
        if (!hasRole(role, msg.sender)) {
            revert AccessControlUnauthorizedAccount(msg.sender, role);
        }
        _;
    }

    constructor() {
        _roles[DEFAULT_ADMIN_ROLE].adminRole = DEFAULT_ADMIN_ROLE;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function hasRole(bytes32 role, address account) public view returns (bool) {
        return _roles[role].members[account];
    }

    function getRoleAdmin(bytes32 role) public view returns (bytes32) {
        bytes32 admin = _roles[role].adminRole;
        if (admin == bytes32(0) && role != DEFAULT_ADMIN_ROLE) {
            return DEFAULT_ADMIN_ROLE;
        }
        return admin;
    }

    function setRoleAdmin(bytes32 role, bytes32 newAdminRole) public onlyRole(DEFAULT_ADMIN_ROLE) {
        bytes32 previous = getRoleAdmin(role);
        _roles[role].adminRole = newAdminRole;
        emit RoleAdminChanged(role, previous, newAdminRole);
    }

    function grantRole(bytes32 role, address account) public onlyRole(getRoleAdmin(role)) {
        _grantRole(role, account);
    }

    function revokeRole(bytes32 role, address account) public onlyRole(getRoleAdmin(role)) {
        _revokeRole(role, account);
    }

    function renounceRole(bytes32 role, address account) public {
        require(account == msg.sender, "Can only renounce roles for self");
        _revokeRole(role, account);
    }

    function _grantRole(bytes32 role, address account) internal {
        if (!_roles[role].members[account]) {
            if (_roles[role].adminRole == bytes32(0) && role != DEFAULT_ADMIN_ROLE) {
                _roles[role].adminRole = DEFAULT_ADMIN_ROLE;
            }
            _roles[role].members[account] = true;
            emit RoleGranted(role, account, msg.sender);
        }
    }

    function _revokeRole(bytes32 role, address account) internal {
        if (_roles[role].members[account]) {
            _roles[role].members[account] = false;
            emit RoleRevoked(role, account, msg.sender);
        }
    }
}

contract DemoRBAC is AccessControlRBAC {
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    string private _message;

    constructor(string memory initialMessage) {
        _message = initialMessage;
        _grantRole(MANAGER_ROLE, msg.sender);
    }

    function setMessage(string calldata newMessage) external onlyRole(MANAGER_ROLE) {
        _message = newMessage;
    }

    function doOperatorThing() external onlyRole(OPERATOR_ROLE) returns (string memory) {
        return _message;
    }

    function message() external view returns (string memory) {
        return _message;
    }
}