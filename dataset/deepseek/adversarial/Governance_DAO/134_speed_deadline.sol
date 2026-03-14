// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/governance/Governor.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorSettings.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorVoting.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorVotingERC20.sol";

contract MyGovernanceToken is ERC20, Ownable {
    constructor() ERC20("MyGovernanceToken", "MGT") {}

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
}

contract MyGovernor is Governor, GovernorSettings, GovernorCountingSimple, GovernorVoting, GovernorVotingERC20 {
    MyGovernanceToken public immutable token;

    constructor(MyGovernanceToken _token, uint256 initialVotingDelay, uint256 initialVotingPeriod, uint256 initialProposalThreshold)
        Governor("MyGovernor")
        GovernorSettings(initialVotingDelay, initialVotingPeriod, initialProposalThreshold)
        GovernorVotingERC20(_token)
    {
        token = _token;
    }

    function votingToken() public view override(Governor, GovernorVotingERC20) returns (IERC20) {
        return token;
    }

    function proposalThreshold() public view override(Governor, GovernorSettings) returns (uint256) {
        return super.proposalThreshold();
    }
}