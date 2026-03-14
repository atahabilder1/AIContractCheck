// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract ExpiringRoleAccess {
    struct Role {
        bool granted;
        uint256 expiresAt;
    }

    address public admin;
    mapping(bytes32 => mapping(address => Role)) private _roles;

    uint256 public defaultDuration = 30 days;

    event RoleGranted(bytes32 indexed role, address indexed account, uint256 expiresAt);
    event RoleRevoked(bytes32 indexed role, address indexed account);
    event RoleRenewed(bytes32 indexed role, address indexed account, uint256 newExpiresAt);
    event DefaultDurationUpdated(uint256 newDuration);
    event AdminTransferred(address indexed previousAdmin, address indexed newAdmin);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Not admin");
        _;
    }

    modifier onlyRole(bytes32 role) {
        require(hasRole(role, msg.sender), "Role missing or expired");
        _;
    }

    constructor() {
        admin = msg.sender;
    }

    function grantRole(bytes32 role, address account, uint256 duration) external onlyAdmin {
        uint256 dur = duration > 0 ? duration : defaultDuration;
        uint256 expiresAt = block.timestamp + dur;
        _roles[role][account] = Role(true, expiresAt);
        emit RoleGranted(role, account, expiresAt);
    }

    function renewRole(bytes32 role, address account, uint256 duration) external onlyAdmin {
        Role storage r = _roles[role][account];
        require(r.granted, "Role not granted");
        uint256 dur = duration > 0 ? duration : defaultDuration;
        uint256 base = r.expiresAt > block.timestamp ? r.expiresAt : block.timestamp;
        r.expiresAt = base + dur;
        emit RoleRenewed(role, account, r.expiresAt);
    }

    function revokeRole(bytes32 role, address account) external onlyAdmin {
        delete _roles[role][account];
        emit RoleRevoked(role, account);
    }

    function hasRole(bytes32 role, address account) public view returns (bool) {
        Role storage r = _roles[role][account];
        return r.granted && block.timestamp <= r.expiresAt;
    }

    function getRoleExpiry(bytes32 role, address account) external view returns (uint256) {
        return _roles[role][account].expiresAt;
    }

    function setDefaultDuration(uint256 newDuration) external onlyAdmin {
        require(newDuration > 0, "Duration must be > 0");
        defaultDuration = newDuration;
        emit DefaultDurationUpdated(newDuration);
    }

    function transferAdmin(address newAdmin) external onlyAdmin {
        require(newAdmin != address(0), "Zero address");
        emit AdminTransferred(admin, newAdmin);
        admin = newAdmin;
    }
}