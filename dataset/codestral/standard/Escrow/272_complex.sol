// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Escrow {
    struct EscrowAgreement {
        address payable[] parties;
        uint256 totalPayment;
        uint256[] milestones;
        address arbiter;
        uint256 timeout;
        bool isDispute;
        bytes[] evidence;
        uint256 releaseTime;
    }

    mapping(uint => EscrowAgreement) public escrowAgreements;
    uint public agreementCount = 0;

    event PaymentReleased(address indexed party, uint amount);
    event DisputeRaised(address indexed disputer, uint agreementId);
    event EvidenceSubmitted(address indexed submitter, uint agreementId);
    event ArbiterDecision(uint agreementId, address payable winner, uint amount);
    event TimeoutRelease(address indexed party, uint agreementId, uint amount);

    constructor() {}

    function createAgreement(address[] memory _parties, uint256 _totalPayment, uint256[] memory _milestones, address _arbiter, uint256 _timeout) public {
        escrowAgreements[agreementCount] = EscrowAgreement(_parties, _totalPayment, _milestones, _arbiter, block.timestamp + _timeout, false, new bytes[](0), 0);
        agreementCount++;
    }

    function submitEvidence(uint _agreementId, bytes memory _evidence) public {
        EscrowAgreement storage agreement = escrowAgreements[_agreementId];
        require(!agreement.isDispute, "Dispute has already been raised.");
        agreement.evidence.push(_evidence);
        emit EvidenceSubmitted(msg.sender, _agreementId);
    }

    function raiseDispute(uint _agreementId) public {
        EscrowAgreement storage agreement = escrowAgreements[_agreementId];
        require(!agreement.isDispute, "Dispute has already been raised.");
        agreement.isDispute = true;
        emit DisputeRaised(msg.sender, _agreementId);
    }

    function makeDecision(uint _agreementId, address payable _winner) public {
        EscrowAgreement storage agreement = escrowAgreements[_agreementId];
        require(agreement.arbiter == msg.sender && agreement.isDispute, "Only the arbiter can make a decision during dispute.");
        uint amountToRelease = agreement.totalPayment;
        for (uint i = 0; i < agreement.milestones.length; i++) {
            if (agreement.parties[i] == _winner) {
                amountToRelease -= agreement.milestones[i];
                break;
            }
        }
        _winner.transfer(amountToRelease);
        emit ArbiterDecision(_agreementId, _winner, amountToRelease);
    }

    function releaseFunds(uint _agreementId) public {
        EscrowAgreement storage agreement = escrowAgreements[_agreementId];
        require(!agreement.isDispute && block.timestamp >= agreement.timeout, "Cannot release funds before timeout or during dispute.");
        for (uint i = 0; i < agreement.parties.length; i++) {
            if (i == agreement.parties.length - 1) {
                uint remainingBalance = agreement.totalPayment;
                for (uint j = 0; j < agreement.milestones.length; j++) {
                    remainingBalance -= agreement.milestones[j];
                }
                agreement.parties[i].transfer(remainingBalance);
            } else {
                agreement.parties[i].transfer(agreement.milestones[i]);
            }
            emit TimeoutRelease(agreement.parties[i], _agreementId, i == agreement.parties.length - 1 ? agreement.totalPayment : agreement.milestones[i]);
        }
    }
}