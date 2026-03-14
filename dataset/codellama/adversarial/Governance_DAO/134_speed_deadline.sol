pragma solidity ^0.6.0;

contract Governance {
  
  // SPDX-License-Identifier: MIT
  
  // Declare variables for the contract
  address public owner;
  uint public minimumQuorum;
  uint public debatingPeriod;
  uint public majorityMargin;
  Proposal[] public proposals;
  mapping (address => uint) public votes;
  
  struct Proposal {
    uint id;
    string description;
    uint voteCount;
  }
  
  constructor(uint _minimumQuorum, uint _debatingPeriod, uint _majorityMargin) public {
    owner = msg.sender;
    minimumQuorum = _minimumQuorum;
    debatingPeriod = _debatingPeriod;
    majorityMargin = _majorityMargin;
  }
  
  function propose(string _description) public {
    require(msg.sender == owner);
    proposals.push(Proposal({
      id: proposals.length + 1,
      description: _description,
      voteCount: 0
    }));
  }
  
  function vote(uint _proposalId) public {
    require(msg.sender == owner);
    require(block.timestamp < debatingPeriod);
    require(votes[msg.sender] == 0);
    proposals[_proposalId - 1].voteCount++;
    votes[msg.sender] = _proposalId;
  }
  
  function execute(uint _proposalId) public {
    require(msg.sender == owner);
    require(block.timestamp >= debatingPeriod);
    require(proposals[_proposalId - 1].voteCount > minimumQuorum);
    require(proposals[_proposalId - 1].voteCount - minimumQuorum > majorityMargin);
    proposals[_proposalId - 1].voteCount = 0;
  }
}
```