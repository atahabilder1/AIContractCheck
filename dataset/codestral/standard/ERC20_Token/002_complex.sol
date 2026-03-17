// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts@4.7.3/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts@4.7.3/access/Ownable.sol";
import "@openzeppelin/contracts@4.7.3/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts@4.7.3/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts@4.7.3/utils/math/SafeMath.sol";
import "@openzeppelin/contracts@4.7.3/token/ERC20/IERC20.sol";
import "./Governor.sol";
import "./VestingSchedule.sol";
import "./Snapshot.sol";

contract ProductionReadyToken is ERC20, Ownable, ReentrancyGuard, ERC20Permit {
    using SafeMath for uint256;

    IERC20 public underlyingToken;
    Governor public governor;
    VestingSchedule public vestingSchedule;
    Snapshot public snapshot;

    constructor(IERC20 _underlyingToken) ERC20("ProductionReadyToken", "PRT") {
        underlyingToken = _underlyingToken;
        governor = new Governor(_underlyingToken, this);
        vestingSchedule = new VestingSchedule(this);
        snapshot = new Snapshot(this);
    }

    // ERC20 functions...
}