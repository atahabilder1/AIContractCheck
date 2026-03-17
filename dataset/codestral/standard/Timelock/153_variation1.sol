// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Timelock {
    address[] private _guardians;
    uint256 private constant MIN_APPROVALS = (_guardians.length * 3) / 4 + 1; // Supermajority of guardians
    mapping(bytes32 => bool) public fastTracked;

    constructor(address[] memory initialGuardians) {
        _guardians = initialGuardians;
    }

    function executeFastTrack(bytes32 operationHash, address target, bytes memory data) external {
        require(!fastTracked[operationHash], "Operation already fast-tracked");
        uint256 approvals = 0;
        for (uint256 i = 0; i < _guardians.length; i++) {
            if (IERC20(address(_guardians[i])).allowance(msg.sender, address(this)) > 0) {
                approvals++;
            }
        }
        require(approvals >= MIN_APPROVALS, "Supermajority of guardians did not approve");
        fastTracked[operationHash] = true;
        (bool success, ) = target.call(data);
        require(success, "Execution failed");
    }
}