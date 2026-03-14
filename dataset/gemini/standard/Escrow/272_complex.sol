// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract EscrowPlatform {

    enum State {
        Created,
        InProgress,
        Disputed,
        Completed,
        Cancelled
    }

    struct Milestone {
        uint256 amount;
        string description;
        bool completed;
        uint256 completionTimestamp;
    }

    struct Dispute {
        bool active;
        address[] evidenceSubmitters;
        string[] evidenceDescriptions;
        address[] potentialArbiters;
        address selectedArbiter;
        bool resolved;
        bool arbiterDecided;
        bool arbiterDecision; // true for buyer, false for seller
        uint256 disputeStartTime;
    }

    address public owner;
    uint256 public constant ARBITER_SELECTION_TIMEOUT = 7 days;
    uint256 public constant DISPUTE_RESOLUTION_TIMEOUT = 14 days;

    address payable public buyer;
    address payable public seller;
    uint256 public totalAmount;
    address payable public arbiter; // Can be set during dispute

    Milestone[] public milestones;
    State public currentState;

    Dispute public currentDispute;

    mapping(address => bool) public hasSubmittedEvidence;

    event EscrowCreated(address indexed _buyer, address indexed _seller, uint256 _totalAmount);
    event MilestoneAdded(uint256 indexed _milestoneId, uint256 _amount, string _description);
    event MilestoneCompleted(uint256 indexed _milestoneId, uint256 _completionTimestamp);
    event FundsDeposited(address indexed _buyer, uint256 _amount);
    event FundsReleased(address indexed _recipient, uint256 _amount);
    event ContractCancelled(address indexed _party);
    event DisputeInitiated(address indexed _initiator);
    event EvidenceSubmitted(address indexed _submitter, string _description);
    event ArbiterSelected(address indexed _arbiter);
    event DisputeResolved(address indexed _arbiter, bool _arbiterDecision);
    event ContractTerminated(address indexed _party);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can perform this action");
        _;
    }

    modifier onlyBuyer() {
        require(msg.sender == buyer, "Only the buyer can perform this action");
        _;
    }

    modifier onlySeller() {
        require(msg.sender == seller, "Only the seller can perform this action");
        _;
    }

    modifier onlyBuyerOrSeller() {
        require(msg.sender == buyer || msg.sender == seller, "Only buyer or seller can perform this action");
        _;
    }

    modifier inState(State _state) {
        require(currentState == _state, "Invalid state transition");
        _;
    }

    constructor() {
        owner = msg.sender;
        currentState = State.Created;
    }

    function createEscrow(address payable _seller, uint256 _totalAmount) external payable onlyBuyer {
        require(currentState == State.Created, "Escrow already created");
        require(_seller != address(0), "Invalid seller address");
        require(_totalAmount > 0, "Total amount must be greater than zero");

        buyer = payable(msg.sender);
        seller = _seller;
        totalAmount = _totalAmount;
        currentState = State.InProgress;

        emit EscrowCreated(buyer, seller, totalAmount);
    }

    function depositFunds() external payable inState(State.InProgress) {
        require(msg.sender == buyer, "Only the buyer can deposit funds");
        require(msg.value == totalAmount, "Incorrect deposit amount");
        emit FundsDeposited(msg.sender, msg.value);
    }

    function addMilestone(string memory _description, uint256 _amount) external onlyBuyer inState(State.InProgress) {
        require(milestones.length < 10, "Maximum number of milestones reached"); // Limit milestones
        require(_amount > 0, "Milestone amount must be greater than zero");
        uint256 currentMilestoneTotal = 0;
        for (uint256 i = 0; i < milestones.length; i++) {
            currentMilestoneTotal += milestones[i].amount;
        }
        require(currentMilestoneTotal + _amount <= totalAmount, "Milestone amounts exceed total escrow amount");

        milestones.push(Milestone({
            amount: _amount,
            description: _description,
            completed: false,
            completionTimestamp: 0
        }));
        emit MilestoneAdded(milestones.length - 1, _amount, _description);
    }

    function completeMilestone(uint256 _milestoneId) external onlySeller inState(State.InProgress) {
        require(_milestoneId < milestones.length, "Invalid milestone ID");
        require(!milestones[_milestoneId].completed, "Milestone already completed");

        uint256 milestoneAmount = milestones[_milestoneId].amount;
        uint256 currentReleasedAmount = 0;
        for (uint256 i = 0; i < _milestoneId; i++) {
            if (milestones[i].completed) {
                currentReleasedAmount += milestones[i].amount;
            }
        }
        require(currentReleasedAmount + milestoneAmount <= totalAmount, "Milestone completion would exceed total escrow amount");

        milestones[_milestoneId].completed = true;
        milestones[_milestoneId].completionTimestamp = block.timestamp;
        emit MilestoneCompleted(_milestoneId, block.timestamp);
    }

    function releaseFunds(uint256 _milestoneId) external onlyBuyer inState(State.InProgress) {
        require(_milestoneId < milestones.length, "Invalid milestone ID");
        require(milestones[_milestoneId].completed, "Milestone not yet completed");

        uint256 amountToRelease = 0;
        for (uint256 i = 0; i <= _milestoneId; i++) {
            if (milestones[i].completed) {
                amountToRelease += milestones[i].amount;
            }
        }

        uint256 alreadyReleased = 0;
        for (uint256 i = 0; i < milestones.length; i++) {
            if (i < _milestoneId && milestones[i].completed) {
                alreadyReleased += milestones[i].amount;
            }
        }

        uint256 releaseAmount = amountToRelease - alreadyReleased;
        require(releaseAmount > 0, "No new funds to release for this milestone");

        (bool success, ) = seller.call{value: releaseAmount}("");
        require(success, "Fund transfer failed");

        emit FundsReleased(seller, releaseAmount);

        // Check if all milestones are completed
        bool allCompleted = true;
        for (uint256 i = 0; i < milestones.length; i++) {
            if (!milestones[i].completed) {
                allCompleted = false;
                break;
            }
        }
        if (allCompleted) {
            currentState = State.Completed;
        }
    }

    function cancelContract() external onlyBuyerOrSeller inState(State.InProgress) {
        // This is a simplified cancellation. In a real-world scenario,
        // cancellation might have conditions or require mutual agreement.
        // For this example, either party can initiate cancellation,
        // and funds go back to the buyer if no milestones are completed.
        // If some milestones are completed, this logic would need to be more complex.

        bool anyMilestoneCompleted = false;
        uint256 completedAmount = 0;
        for (uint256 i = 0; i < milestones.length; i++) {
            if (milestones[i].completed) {
                anyMilestoneCompleted = true;
                completedAmount += milestones[i].amount;
                break; // If any milestone is completed, cannot simply cancel and refund
            }
        }

        if (!anyMilestoneCompleted) {
            (bool success, ) = buyer.call{value: address(this).balance}("");
            require(success, "Refund failed");
            currentState = State.Cancelled;
            emit ContractCancelled(msg.sender);
        } else {
            // If any milestone is completed, cancellation should likely go to dispute
            initiateDispute("Contract cancellation requested by " + (msg.sender == buyer ? "buyer" : "seller"));
        }
    }

    function initiateDispute(string memory _reason) external onlyBuyerOrSeller inState(State.InProgress) {
        require(!currentDispute.active, "A dispute is already active");
        require(currentState == State.InProgress, "Contract must be in progress to initiate dispute");

        currentDispute = Dispute({
            active: true,
            evidenceSubmitters: new address[](0),
            evidenceDescriptions: new string[](0),
            potentialArbiters: new address[](0),
            selectedArbiter: payable(address(0)),
            resolved: false,
            arbiterDecided: false,
            arbiterDecision: false,
            disputeStartTime: block.timestamp
        });

        // In a real system, potential arbiters might be selected from a pre-approved list or through a staking mechanism.
        // For simplicity here, we'll allow the initiator to suggest an arbiter, and the other party can accept or suggest another.
        // Or, a default arbiter could be assigned.
        // For this example, let's say the initiator can add themselves as a potential arbiter and the other party can add another.
        // Or, more simply, the contract can just mark it as disputed and the arbiter selection process begins.

        // For this example, we'll just mark it as disputed and rely on timeout for arbiter selection if no manual selection happens.
        // A more robust system would have a more defined arbiter selection process.
        currentState = State.Disputed;
        emit DisputeInitiated(msg.sender);
    }

    function submitEvidence(string memory _description) external onlyBuyerOrSeller inState(State.Disputed) {
        require(currentDispute.active, "No active dispute");
        require(!hasSubmittedEvidence[msg.sender], "You have already submitted evidence");

        currentDispute.evidenceSubmitters.push(msg.sender);
        currentDispute.evidenceDescriptions.push(_description);
        hasSubmittedEvidence[msg.sender] = true;

        emit EvidenceSubmitted(msg.sender, _description);
    }

    function selectArbiter(address payable _arbiter) external onlyBuyerOrSeller inState(State.Disputed) {
        require(currentDispute.active, "No active dispute");
        require(_arbiter != address(0), "Invalid arbiter address");
        require(currentDispute.selectedArbiter == payable(address(0)), "Arbiter already selected");

        // Simple arbiter selection: if one party proposes an arbiter, the other party must agree or propose another.
        // For simplicity here, if either party proposes an arbiter and the other doesn't object within a timeout, it's selected.
        // A better approach: both parties propose, or a list of arbiters is provided.
        // For this example, let's allow either party to set the arbiter once.
        // The other party can then confirm or propose a different one.

        // If no arbiter has been selected yet, set the proposed arbiter.
        if (currentDispute.selectedArbiter == payable(address(0))) {
            currentDispute.selectedArbiter = _arbiter;
            emit ArbiterSelected(_arbiter);
        } else if (currentDispute.selectedArbiter != _arbiter) {
            // If a different arbiter is proposed, the other party has to agree.
            // This is a simplification. A real system would have a more robust negotiation.
            // For this example, we'll just allow the last proposed arbiter to be the one,
            // assuming the other party would have objected if they didn't agree.
            // A better model: require explicit agreement from both parties.
            currentDispute.selectedArbiter = _arbiter;
            emit ArbiterSelected(_arbiter);
        }
        // If the same arbiter is proposed again, it's confirmed.
        else {
            // Arbiter already selected and is the same.
        }

        // Check if arbiter is selected and if it's the same one proposed by both parties or by one and accepted by the other.
        // For simplicity, we assume the arbiter is effectively selected if set.
        // A more advanced mechanism would involve a voting or agreement process.
    }

    function resolveDispute(bool _arbiterDecision) external inState(State.Disputed) {
        require(currentDispute.active, "No active dispute");
        require(currentDispute.selectedArbiter != payable(address(0)), "Arbiter not yet selected");
        require(msg.sender == currentDispute.selectedArbiter, "Only the selected arbiter can resolve the dispute");
        require(!currentDispute.arbiterDecided, "Dispute already decided by arbiter");

        currentDispute.arbiterDecided = true;
        currentDispute.arbiterDecision = _arbiterDecision; // true for buyer win, false for seller win
        emit DisputeResolved(msg.sender, _arbiterDecision);

        if (_arbiterDecision) { // Buyer wins dispute
            // Release funds to buyer
            (bool success, ) = buyer.call{value: address(this).balance}("");
            require(success, "Fund transfer to buyer failed");
            emit FundsReleased(buyer, address(this).balance);
            currentState = State.Completed;
        } else { // Seller wins dispute
            // Release funds to seller
            (bool success, ) = seller.call{value: address(this).balance}("");
            require(success, "Fund transfer to seller failed");
            emit FundsReleased(seller, address(this).balance);
            currentState = State.Completed;
        }
    }

    function checkTimeouts() external {
        if (currentState == State.Disputed) {
            // Check for arbiter selection timeout
            if (currentDispute.selectedArbiter == payable(address(0)) &&
                block.timestamp >= currentDispute.disputeStartTime + ARBITER_SELECTION_TIMEOUT) {
                // No arbiter selected, initiate a process for automatic arbiter assignment or refund to buyer
                // For simplicity, let's assume funds are returned to buyer if arbiter not selected in time.
                // A more complex system might involve a default arbiter.
                (bool success, ) = buyer.call{value: address(this).balance}("");
                require(success, "Refund to buyer on arbiter timeout failed");
                emit FundsReleased(buyer, address(this).balance);
                currentState = State.Completed; // Or a specific 'TimedOut' state
                emit ContractTerminated(buyer);
            }

            // Check for dispute resolution timeout (if arbiter was selected but hasn't decided)
            if (currentDispute.selectedArbiter != payable(address(0)) &&
                !currentDispute.arbiterDecided &&
                block.timestamp >= currentDispute.disputeStartTime + DISPUTE_RESOLUTION_TIMEOUT) {
                // Arbiter failed to decide within the timeout.
                // This is a tricky scenario. Options:
                // 1. Default to buyer (arbitration is usually for buyer protection)
                // 2. Default to seller (if evidence strongly favored seller)
                // 3. Re-initiate dispute or select a new arbiter.
                // For simplicity, let's assume funds are returned to buyer.
                (bool success, ) = buyer.call{value: address(this).balance}("");
                require(success, "Refund to buyer on resolution timeout failed");
                emit FundsReleased(buyer, address(this).balance);
                currentState = State.Completed; // Or a specific 'TimedOut' state
                emit ContractTerminated(buyer);
            }
        }
    }

    // Fallback function to receive Ether
    receive() external payable {
        // Can be used for direct deposits in some scenarios, but `depositFunds` is preferred.
    }

    // Function to withdraw remaining balance if contract is cancelled or completed by owner
    function withdrawRemainingBalance() external onlyOwner {
        require(currentState == State.Cancelled || currentState == State.Completed, "Contract not in a state to withdraw remaining balance");
        (bool success, ) = payable(owner).call{value: address(this).balance}("");
        require(success, "Withdrawal of remaining balance failed");
    }
}