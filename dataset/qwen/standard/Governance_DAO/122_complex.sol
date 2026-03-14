// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/governance/Governor.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorSettings.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorTimelockControl.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";

contract CompoundLikeGovernor is
    Governor,
    GovernorSettings,
    GovernorCountingSimple,
    GovernorVotes,
    GovernorVotesQuorumFraction,
    GovernorTimelockControl,
    EIP712
{
    uint256 public constant MIN_DELAY = 2 * 24 * 60 * 60; // 2 days minimum delay for actions

    constructor(
        ERC20Votes _token,
        TimelockController _timelock
    )
        Governor("CompoundLikeGovernor")
        GovernorSettings(1 /* 1 block */, 45818 /* 1 week */, 0)
        GovernorVotes(_token)
        GovernorVotesQuorumFraction(4)
        GovernorTimelockControl(_timelock)
        EIP712("CompoundLikeGovernor", "1")
    {}

    function cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 salt
    ) public override returns (uint256 proposalId) {
        proposalId = hashProposal(targets, values, calldatas, salt);
        require(state(proposalId) != ProposalState.Executed, "Governor: cannot cancel executed proposal");

        _cancel(targets, values, calldatas, salt);
        emit ProposalCanceled(proposalId);

        return proposalId;
    }

    function _cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 salt
    ) internal virtual {
        uint256 proposalId = hashProposal(targets, values, calldatas, salt);
        require(state(proposalId) != ProposalState.Executed, "Governor: cannot cancel executed proposal");

        _cancelActiveProposal(proposalId);
    }

    function _cancelActiveProposal(uint256 proposalId) internal virtual {
        ProposalState status = state(proposalId);
        require(
            status != ProposalState.Executed && status != ProposalState.Canceled,
            "Governor: proposal not active"
        );

        _proposals[proposalId].canceled = true;
    }

    // The following functions are overrides required by Solidity.

    function quorum(uint256 blockNumber) public view override(IGovernor, GovernorVotesQuorumFraction) returns (uint256) {
        return super.quorum(blockNumber);
    }

    function getVotes(address account, uint256 blockNumber) public view override(IGovernor, GovernorVotes) returns (uint256) {
        return super.getVotes(account, blockNumber);
    }

    function state(uint256 proposalId) public view override(Governor, GovernorTimelockControl) returns (ProposalState) {
        return super.state(proposalId);
    }

    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) public override(IGovernor, Governor) returns (uint256) {
        return super.propose(targets, values, calldatas, description);
    }

    function execute(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 salt
    ) public payable override(Governor, GovernorTimelockControl) returns (uint256) {
        return super.execute(targets, values, calldatas, salt);
    }

    function _execute(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) {
        super._execute(proposalId, targets, values, calldatas, descriptionHash);
    }

    function _queueOperations(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 salt
    ) internal override(Governor, GovernorTimelockControl) returns (uint256) {
        return super._queueOperations(targets, values, calldatas, salt);
    }

    function _castVote(
        uint256 proposalId,
        address account,
        uint8 support
    ) internal override returns (uint256) {
        return super._castVote(proposalId, account, support);
    }

    function _countVote(
        uint256 proposalId,
        address account,
        uint8 support,
        uint256 weight
    ) internal override(Governor, GovernorCountingSimple) {
        super._countVote(proposalId, account, support, weight);
    }
}