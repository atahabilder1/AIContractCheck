// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract EscrowPlatform is Ownable, ReentrancyGuard {
    struct Milestone {
        uint256 amount;
        bool released;
        bool disputed;
        mapping(address => bool) approved;
    }

    struct Escrow {
        address buyer;
        address seller;
        mapping(uint256 => Milestone) milestones;
        uint256 totalMilestones;
        uint256 timeout;
        address arbiter;
        bool resolved;
        bool disputed;
        mapping(address => bool) approved;
    }

    mapping(uint256 => Escrow) public escrows;
    uint256 public escrowCount;

    event MilestoneReleased(uint256 escrowId, uint256 milestoneIndex);
    event EscrowDisputed(uint256 escrowId);
    event EscrowResolved(uint256 escrowId);

    function createEscrow(address _buyer, address _seller, uint256 _timeout) public {
        Escrow storage escrow = escrows[escrowCount];
        escrow.buyer = _buyer;
        escrow.seller = _seller;
        escrow.timeout = block.timestamp + _timeout;
        escrowCount++;
    }

    function addMilestone(uint256 _escrowId, uint256 _amount) public {
        Escrow storage escrow = escrows[_escrowId];
        require(msg.sender == escrow.buyer || msg.sender == escrow.seller, "Not authorized");
        escrow.milestones[_escrowCount] = Milestone({amount: _amount, released: false, disputed: false});
        escrow.totalMilestones++;
    }

    function approveMilestone(uint256 _escrowId, uint256 _milestoneIndex) public {
        Escrow storage escrow = escrows[_escrowId];
        require(msg.sender == escrow.buyer || msg.sender == escrow.seller, "Not authorized");
        require(!escrow.milestones[_milestoneIndex].released, "Milestone already released");
        escrow.milestones[_milestoneIndex].approved[msg.sender] = true;
    }

    function releaseMilestone(uint256 _escrowId, uint256 _milestoneIndex) public {
        Escrow storage escrow = escrows[_escrowId];
        require(msg.sender == escrow.seller, "Only seller can release milestone");
        require(!escrow.milestones[_milestoneIndex].released, "Milestone already released");
        require(!escrow.milestones[_milestoneIndex].disputed, "Milestone is disputed");
        require(escrow.milestones[_milestoneIndex].approved[escrow.buyer], "Buyer has not approved milestone");
        escrow.milestones[_milestoneIndex].released = true;
        emit MilestoneReleased(_escrowId, _milestoneIndex);
    }

    function disputeEscrow(uint256 _escrowId) public {
        Escrow storage escrow = escrows[_escrowId];
        require(msg.sender == escrow.buyer || msg.sender == escrow.seller, "Not authorized");
        require(!escrow.disputed, "Escrow is already disputed");
        escrow.disputed = true;
        emit EscrowDisputed(_escrowId);
    }

    function resolveEscrow(uint256 _escrowId) public {
        Escrow storage escrow = escrows[_escrowId];
        require(msg.sender == escrow.arbiter, "Only arbiter can resolve escrow");
        require(escrow.disputed, "Escrow is not disputed");
        require(block.timestamp > escrow.timeout, "Timeout not reached");
        escrow.resolved = true;
        emit EscrowResolved(_escrowId);
    }
}