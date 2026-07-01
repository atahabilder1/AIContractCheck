// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract HierarchicalRBAC is AccessControl, ReentrancyGuard {
    using EnumerableSet for EnumerableSet.Bytes32Set;
    using EnumerableSet for EnumerableSet.AddressSet;

    // Role hierarchy mapping: role => parent role
    mapping(bytes32 => bytes32) private _roleHierarchy;
    
    // Role members enumeration
    mapping(bytes32 => EnumerableSet.AddressSet) private _roleMembers;
    
    // All roles enumeration
    EnumerableSet.Bytes32Set private _allRoles;
    
    // Role metadata
    struct RoleInfo {
        string name;
        string description;
        bool exists;
        uint256 createdAt;
    }
    
    mapping(bytes32 => RoleInfo) private _roleInfo;

    // Events
    event RoleCreated(bytes32 indexed role, string name, bytes32 indexed parentRole);
    event RoleHierarchyUpdated(bytes32 indexed role, bytes32 indexed oldParent, bytes32 indexed newParent);
    event RoleInfoUpdated(bytes32 indexed role, string name, string description);

    // Custom errors
    error InvalidAddress();
    error RoleNotExists();
    error RoleAlreadyExists();
    error InvalidHierarchy();
    error SelfReference();
    error CircularReference();

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _createRole(DEFAULT_ADMIN_ROLE, "Admin", "Default admin role", bytes32(0));
    }

    /**
     * @dev Modifier to check if caller has role or any parent role in hierarchy
     */
    modifier onlyRoleOrParent(bytes32 role) {
        require(hasRoleOrParent(msg.sender, role), "AccessControl: account missing required role");
        _;
    }

    /**
     * @dev Modifier to check if caller has exact role (no hierarchy check)
     */
    modifier onlyExactRole(bytes32 role) {
        require(hasRole(role, msg.sender), "AccessControl: account missing exact role");
        _;
    }

    /**
     * @dev Create a new role with hierarchy
     */
    function createRole(
        bytes32 role,
        string calldata name,
        string calldata description,
        bytes32 parentRole
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (role == bytes32(0)) revert InvalidAddress();
        if (_roleInfo[role].exists) revert RoleAlreadyExists();
        if (parentRole != bytes32(0) && !_roleInfo[parentRole].exists) revert RoleNotExists();
        if (role == parentRole) revert SelfReference();

        _createRole(role, name, description, parentRole);
    }

    /**
     * @dev Update role hierarchy
     */
    function updateRoleHierarchy(
        bytes32 role,
        bytes32 newParentRole
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (!_roleInfo[role].exists) revert RoleNotExists();
        if (newParentRole != bytes32(0) && !_roleInfo[newParentRole].exists) revert RoleNotExists();
        if (role == newParentRole) revert SelfReference();
        if (_wouldCreateCircularReference(role, newParentRole)) revert CircularReference();

        bytes32 oldParent = _roleHierarchy[role];
        _roleHierarchy[role] = newParentRole;

        emit RoleHierarchyUpdated(role, oldParent, newParentRole);
    }

    /**
     * @dev Update role information
     */
    function updateRoleInfo(
        bytes32 role,
        string calldata name,
        string calldata description
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (!_roleInfo[role].exists) revert RoleNotExists();

        _roleInfo[role].name = name;
        _roleInfo[role].description = description;

        emit RoleInfoUpdated(role, name, description);
    }

    /**
     * @dev Grant role with input validation
     */
    function grantRole(
        bytes32 role,
        address account
    ) public override onlyRole(getRoleAdmin(role)) {
        if (account == address(0)) revert InvalidAddress();
        if (!_roleInfo[role].exists) revert RoleNotExists();

        _grantRole(role, account);
        _roleMembers[role].add(account);
    }

    /**
     * @dev Revoke role with cleanup
     */
    function revokeRole(
        bytes32 role,
        address account
    ) public override onlyRole(getRoleAdmin(role)) {
        if (account == address(0)) revert InvalidAddress();
        if (!_roleInfo[role].exists) revert RoleNotExists();

        _revokeRole(role, account);
        _roleMembers[role].remove(account);
    }

    /**
     * @dev Renounce role with cleanup
     */
    function renounceRole(
        bytes32 role,
        address account
    ) public override {
        if (account == address(0)) revert InvalidAddress();
        require(account == msg.sender, "AccessControl: can only renounce roles for self");

        _revokeRole(role, account);
        _roleMembers[role].remove(account);
    }

    /**
     * @dev Batch grant roles
     */
    function batchGrantRoles(
        bytes32[] calldata roles,
        address[] calldata accounts
    ) external nonReentrant {
        require(roles.length == accounts.length, "Arrays length mismatch");
        require(roles.length > 0, "Empty arrays");

        for (uint256 i = 0; i < roles.length; i++) {
            grantRole(roles[i], accounts[i]);
        }
    }

    /**
     * @dev Batch revoke roles
     */
    function batchRevokeRoles(
        bytes32[] calldata roles,
        address[] calldata accounts
    ) external nonReentrant {
        require(roles.length == accounts.length, "Arrays length mismatch");
        require(roles.length > 0, "Empty arrays");

        for (uint256 i = 0; i < roles.length; i++) {
            revokeRole(roles[i], accounts[i]);
        }
    }

    /**
     * @dev Check if account has role or any parent role in hierarchy
     */
    function hasRoleOrParent(address account, bytes32 role) public view returns (bool) {
        if (account == address(0)) return false;
        
        // Check direct role
        if (hasRole(role, account)) {
            return true;
        }

        // Check parent roles up the hierarchy
        bytes32 currentRole = role;
        bytes32 parentRole = _roleHierarchy[currentRole];
        
        while (parentRole != bytes32(0)) {
            if (hasRole(parentRole, account)) {
                return true;
            }
            currentRole = parentRole;
            parentRole = _roleHierarchy[currentRole];
        }

        return false;
    }

    /**
     * @dev Get role parent
     */
    function getRoleParent(bytes32 role) external view returns (bytes32) {
        return _roleHierarchy[role];
    }

    /**
     * @dev Get role information
     */
    function getRoleInfo(bytes32 role) external view returns (RoleInfo memory) {
        return _roleInfo[role];
    }

    /**
     * @dev Get all role members
     */
    function getRoleMembers(bytes32 role) external view returns (address[] memory) {
        return _roleMembers[role].values();
    }

    /**
     * @dev Get role member count
     */
    function getRoleMemberCount(bytes32 role) external view returns (uint256) {
        return _roleMembers[role].length();
    }

    /**
     * @dev Get role member at index
     */
    function getRoleMemberAt(bytes32 role, uint256 index) external view returns (address) {
        return _roleMembers[role].at(index);
    }

    /**
     * @dev Get all roles
     */
    function getAllRoles() external view returns (bytes32[] memory) {
        return _allRoles.values();
    }

    /**
     * @dev Get total roles count
     */
    function getRoleCount() external view returns (uint256) {
        return _allRoles.length();
    }

    /**
     * @dev Get role hierarchy path
     */
    function getRoleHierarchyPath(bytes32 role) external view returns (bytes32[] memory) {
        bytes32[] memory path = new bytes32[](10); // Max depth of 10
        uint256 length = 0;
        bytes32 currentRole = role;

        while (currentRole != bytes32(0) && length < 10) {
            path[length] = currentRole;
            length++;
            currentRole = _roleHierarchy[currentRole];
        }

        // Resize array to actual length
        bytes32[] memory result = new bytes32[](length);
        for (uint256 i = 0; i < length; i++) {
            result[i] = path[i];
        }

        return result;
    }

    /**
     * @dev Internal function to create role
     */
    function _createRole(
        bytes32 role,
        string memory name,
        string memory description,
        bytes32 parentRole
    ) private {
        _roleInfo[role] = RoleInfo({
            name: name,
            description: description,
            exists: true,
            createdAt: block.timestamp
        });

        _roleHierarchy[role] = parentRole;
        _allRoles.add(role);

        emit RoleCreated(role, name, parentRole);
    }

    /**
     * @dev Check if setting parent would create circular reference
     */
    function _wouldCreateCircularReference(
        bytes32 role,
        bytes32 newParentRole
    ) private view returns (bool) {
        bytes32 currentRole = newParentRole;
        
        while (currentRole != bytes32(0)) {
            if (currentRole == role) {
                return true;
            }
            currentRole = _roleHierarchy[currentRole];
        }

        return false;
    }
}