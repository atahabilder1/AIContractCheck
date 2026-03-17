// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract SimpleDAO is Ownable {
    using SafeMath for uint256;

    IERC20 public token;
    struct Proposal {
        string description;
        uint votesFor;
        bool executed;
    }

    mapping(uint => Proposal) public proposals;
    uint public proposalCount = 0;

    constructor(address _token) {
        token = IERC20(_token);
    }

    function createProposal(string memory _description) external {
        proposals[proposalCount] = Proposal(_description, 0, false);
        proposalCount++;
    }

    function voteFor(uint _proposalId) external {
        require(_proposalId < proposalCount, "Invalid proposal ID");
        require(!proposals[_proposalId].executed, "Proposal already executed");

        uint balance = token.balanceOf(msg.sender);
        require(balance > 0, "No tokens to vote with");

        proposals[_proposalId].votesFor = proposals[_proposalId].votesFor.add(balance);
    }

    function executeProposal(uint _proposalId) external onlyOwner {
        require(_proposalId < proposalCount, "Invalid proposal ID");
        Proposal memory proposal = proposals[_proposalId];
        require(!proposal.executed, "Proposal already executed");

        // Execute the proposal here
    }
}