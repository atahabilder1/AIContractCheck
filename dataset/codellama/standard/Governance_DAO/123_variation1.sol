// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract QuadraticVotingDAO {
    struct Member {
        address memberAddress;
        uint256 tokensHeld;
        uint256 votingPower;
    }

    mapping(address => Member) public members;
    mapping(address => uint256) public tokens;
    uint256 public totalTokens;

    constructor() public {
        totalTokens = 0;
    }

    function addMember(address _memberAddress) public {
        require(members[_memberAddress].memberAddress == address(0), "Member already exists");
        members[_memberAddress] = Member({
            memberAddress: _memberAddress,
            tokensHeld: 0,
            votingPower: 0
        });
    }

    function addTokens(address _memberAddress, uint256 _tokens) public {
        require(members[_memberAddress].memberAddress != address(0), "Member does not exist");
        require(tokens[_memberAddress] + _tokens > tokens[_memberAddress], "Tokens must be greater than zero");
        tokens[_memberAddress] += _tokens;
        totalTokens += _tokens;
        updateVotingPower(_memberAddress);
    }

    function removeTokens(address _memberAddress, uint256 _tokens) public {
        require(members[_memberAddress].memberAddress != address(0), "Member does not exist");
        require(tokens[_memberAddress] - _tokens >= 0, "Tokens must be greater than zero");
        tokens[_memberAddress] -= _tokens;
        totalTokens -= _tokens;
        updateVotingPower(_memberAddress);
    }

    function updateVotingPower(address _memberAddress) public {
        require(members[_memberAddress].memberAddress != address(0), "Member does not exist");
        members[_memberAddress].votingPower = sqrt(tokens[_memberAddress]);
    }

    function getVotingPower(address _memberAddress) public view returns (uint256) {
        require(members[_memberAddress].memberAddress != address(0), "Member does not exist");
        return members[_memberAddress].votingPower;
    }

    function getTotalTokens() public view returns (uint256) {
        return totalTokens;
    }
}