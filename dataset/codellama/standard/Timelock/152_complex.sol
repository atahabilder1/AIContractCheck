// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract TimelockController {
    // Role definitions
    enum Role {
        ADMIN,
        OPERATOR,
        USER
    }

    // Timelock data structure
    struct Timelock {
        uint256 id;
        uint256 startTime;
        uint256 endTime;
        uint256 delay;
        uint256 predecessorId;
        uint256 successorId;
    }

    // Mapping of role to timelocks
    mapping(Role => mapping(uint256 => Timelock)) private _timelocks;

    // Mapping of predecessor to successor
    mapping(uint256 => uint256) private _predecessors;

    // Mapping of successor to predecessor
    mapping(uint256 => uint256) private _successors;

    // Mapping of role to number of timelocks
    mapping(Role => uint256) private _numTimelocks;

    // Mapping of role to timelock ids
    mapping(Role => uint256[]) private _timelockIds;

    // Mapping of role to timelock ids with predecessors
    mapping(Role => uint256[]) private _timelockIdsWithPredecessors;

    // Mapping of role to timelock ids with successors
    mapping(Role => uint256[]) private _timelockIdsWithSuccessors;

    // Mapping of role to timelock ids with predecessors and successors
    mapping(Role => uint256[]) private _timelockIdsWithPredecessorsAndSuccessors;

    constructor() {
        // Initialize role-based timelocks
        _timelocks[Role.ADMIN] = new mapping(uint256 => Timelock);
        _timelocks[Role.OPERATOR] = new mapping(uint256 => Timelock);
        _timelocks[Role.USER] = new mapping(uint256 => Timelock);

        // Initialize timelock ids
        _timelockIds[Role.ADMIN] = new uint256[];
        _timelockIds[Role.OPERATOR] = new uint256[];
        _timelockIds[Role.USER] = new uint256[];

        // Initialize timelock ids with predecessors
        _timelockIdsWithPredecessors[Role.ADMIN] = new uint256[];
        _timelockIdsWithPredecessors[Role.OPERATOR] = new uint256[];
        _timelockIdsWithPredecessors[Role.USER] = new uint256[];

        // Initialize timelock ids with successors
        _timelockIdsWithSuccessors[Role.ADMIN] = new uint256[];
        _timelockIdsWithSuccessors[Role.OPERATOR] = new uint256[];
        _timelockIdsWithSuccessors[Role.USER] = new uint256[];

        // Initialize timelock ids with predecessors and successors
        _timelockIdsWithPredecessorsAndSuccessors[Role.ADMIN] = new uint256[];
        _timelockIdsWithPredecessorsAndSuccessors[Role.OPERATOR] = new uint256[];
        _timelockIdsWithPredecessorsAndSuccessors[Role.USER] = new uint256[];
    }

    function addTimelock(
        Role role,
        uint256 startTime,
        uint256 endTime,
        uint256 delay,
        uint256 predecessorId,
        uint256 successorId
    ) public {
        // Check if timelock already exists
        if (_timelocks[role][startTime] != 0) {
            revert("Timelock already exists");
        }

        // Create new timelock
        Timelock timelock = new Timelock(startTime, endTime, delay, predecessorId, successorId);

        // Add timelock to role-based timelocks
        _timelocks[role][startTime] = timelock;

        // Add timelock to timelock ids
        _timelockIds[role].push(startTime);

        // Add timelock to timelock ids with predecessors
        _timelockIdsWithPredecessors[role].push(startTime);

        // Add timelock to timelock ids with successors
        _timelockIdsWithSuccessors[role].push(startTime);

        // Add timelock to timelock ids with predecessors and successors
        _timelockIdsWithPredecessorsAndSuccessors[role].push(startTime);
    }

    function getTimelock(Role role, uint256 startTime) public view returns (Timelock) {
        return _timelocks[role][startTime];
    }

    function getTimelocks(Role role) public view returns (mapping(uint256 => Timelock)) {
        return _timelocks[role];
    }

    function getTimelockIds(Role role) public view returns (uint256[]) {
        return _timelockIds[role];
    }

    function getTimelockIdsWithPredecessors(Role role) public view returns (uint256[]) {
        return _timelockIdsWithPredecessors[role];
    }

    function getTimelockIdsWithSuccessors(Role role) public view returns (uint256[]) {
        return _timelockIdsWithSuccessors[role];
    }

    function getTimelockIdsWithPredecessorsAndSuccessors(Role role) public view returns (uint256[]) {
        return _timelockIdsWithPredecessorsAndSuccessors[role];
    }
}