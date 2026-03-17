// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract SimpleDAO {
    uint256 public constant VOTING_PERIOD = 3 days;

    struct Proposal {
        address target;
        uint256 value;
        bytes data;
        uint256 start;
        uint256 end;
        uint256 yes;
        uint256 no;
        bool executed;
        mapping(address => bool) voted;
    }

    uint256 public proposalCount;
    mapping(uint256 => Proposal) private proposals;

    function propose(address target, uint256 value, bytes calldata data) external returns (uint256 id) {
        require(target != address(0), "invalid target");
        id = ++proposalCount;
        Proposal storage p = proposals[id];
        p.target = target;
        p.value = value;
        p.data = data;
        p.start = block.timestamp;
        p.end = block.timestamp + VOTING_PERIOD;
    }

    function vote(uint256 id, bool support) external {
        Proposal storage p = proposals[id];
        require(p.end != 0, "no proposal");
        require(block.timestamp < p.end, "voting ended");
        require(!p.voted[msg.sender], "already voted");
        p.voted[msg.sender] = true;
        if (support) {
            p.yes++;
        } else {
            p.no++;
        }
    }

    function execute(uint256 id) external {
        Proposal storage p = proposals[id];
        require(p.end != 0, "no proposal");
        require(block.timestamp >= p.end, "not ended");
        require(!p.executed, "executed");
        require(p.yes > p.no, "did not pass");
        p.executed = true;
        (bool ok, ) = p.target.call{value: p.value}(p.data);
        require(ok, "call failed");
    }

    function getProposal(uint256 id) external view returns (
        address target,
        uint256 value,
        uint256 start,
        uint256 end,
        uint256 yes,
        uint256 no,
        bool executed
    ) {
        Proposal storage p = proposals[id];
        return (p.target, p.value, p.start, p.end, p.yes, p.no, p.executed);
    }

    receive() external payable {}
}