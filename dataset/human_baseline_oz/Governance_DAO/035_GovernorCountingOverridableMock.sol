// Source: OpenZeppelin Contracts (GitHub)
// Original Path: mocks/governance/GovernorCountingOverridableMock.sol
// License: MIT
// Collected: 2026-03-16T17:54:55.910171

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Governor} from "../../governance/Governor.sol";
import {GovernorSettings} from "../../governance/extensions/GovernorSettings.sol";
import {GovernorVotesQuorumFraction} from "../../governance/extensions/GovernorVotesQuorumFraction.sol";
import {GovernorCountingOverridable} from "../../governance/extensions/GovernorCountingOverridable.sol";

abstract contract GovernorCountingOverridableMock is
    GovernorSettings,
    GovernorVotesQuorumFraction,
    GovernorCountingOverridable
{
    function proposalThreshold() public view override(Governor, GovernorSettings) returns (uint256) {
        return super.proposalThreshold();
    }
}
