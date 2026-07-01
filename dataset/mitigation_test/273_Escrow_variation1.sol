// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract FreelanceEscrow is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    struct Milestone {
        string description;
        uint256 amount;
        bool completed;
        bool approved;
        bool disputed;
    }

    struct Project {
        address client;
        address freelancer;
        IERC20 token;
        uint256 totalAmount;
        uint256 releasedAmount;
        uint256 milestoneCount;
        bool active;
        mapping(uint256 => Milestone) milestones;
    }

    mapping(uint256 => Project) public projects;
    uint256 public projectCounter;
    uint256 public constant DISPUTE_TIMEOUT = 7 days;
    uint256 public platformFee = 250; // 2.5%
    uint256 public constant MAX_FEE = 1000; // 10%

    event ProjectCreated(
        uint256 indexed projectId,
        address indexed client,
        address indexed freelancer,
        address token,
        uint256 totalAmount
    );
    
    event MilestoneCompleted(
        uint256 indexed projectId,
        uint256 indexed milestoneId,
        address indexed freelancer
    );
    
    event MilestoneApproved(
        uint256 indexed projectId,
        uint256 indexed milestoneId,
        address indexed client,
        uint256 amount
    );
    
    event MilestoneDisputed(
        uint256 indexed projectId,
        uint256 indexed milestoneId,
        address indexed disputer
    );
    
    event DisputeResolved(
        uint256 indexed projectId,
        uint256 indexed milestoneId,
        bool approvedByAdmin
    );
    
    event ProjectCancelled(uint256 indexed projectId);

    modifier onlyClient(uint256 _projectId) {
        require(projects[_projectId].client == msg.sender, "Only client can call this");
        _;
    }

    modifier onlyFreelancer(uint256 _projectId) {
        require(projects[_projectId].freelancer == msg.sender, "Only freelancer can call this");
        _;
    }

    modifier onlyProjectParticipant(uint256 _projectId) {
        require(
            projects[_projectId].client == msg.sender || 
            projects[_projectId].freelancer == msg.sender,
            "Only project participants can call this"
        );
        _;
    }

    modifier projectExists(uint256 _projectId) {
        require(_projectId < projectCounter, "Project does not exist");
        require(projects[_projectId].active, "Project is not active");
        _;
    }

    modifier validMilestone(uint256 _projectId, uint256 _milestoneId) {
        require(_milestoneId < projects[_projectId].milestoneCount, "Invalid milestone");
        _;
    }

    function createProject(
        address _freelancer,
        address _token,
        uint256 _totalAmount,
        string[] calldata _milestoneDescriptions,
        uint256[] calldata _milestoneAmounts
    ) external nonReentrant returns (uint256) {
        require(_freelancer != address(0), "Invalid freelancer address");
        require(_freelancer != msg.sender, "Client cannot be freelancer");
        require(_token != address(0), "Invalid token address");
        require(_totalAmount > 0, "Total amount must be greater than 0");
        require(_milestoneDescriptions.length > 0, "At least one milestone required");
        require(
            _milestoneDescriptions.length == _milestoneAmounts.length,
            "Mismatched milestone arrays"
        );

        uint256 sumAmounts = 0;
        for (uint256 i = 0; i < _milestoneAmounts.length; i++) {
            require(_milestoneAmounts[i] > 0, "Milestone amount must be greater than 0");
            require(bytes(_milestoneDescriptions[i]).length > 0, "Empty milestone description");
            sumAmounts += _milestoneAmounts[i];
        }
        require(sumAmounts == _totalAmount, "Milestone amounts don't match total");

        uint256 projectId = projectCounter++;
        Project storage project = projects[projectId];
        
        project.client = msg.sender;
        project.freelancer = _freelancer;
        project.token = IERC20(_token);
        project.totalAmount = _totalAmount;
        project.releasedAmount = 0;
        project.milestoneCount = _milestoneDescriptions.length;
        project.active = true;

        for (uint256 i = 0; i < _milestoneDescriptions.length; i++) {
            project.milestones[i] = Milestone({
                description: _milestoneDescriptions[i],
                amount: _milestoneAmounts[i],
                completed: false,
                approved: false,
                disputed: false
            });
        }

        project.token.safeTransferFrom(msg.sender, address(this), _totalAmount);

        emit ProjectCreated(projectId, msg.sender, _freelancer, _token, _totalAmount);
        return projectId;
    }

    function completeMilestone(
        uint256 _projectId,
        uint256 _milestoneId
    ) external projectExists(_projectId) validMilestone(_projectId, _milestoneId) onlyFreelancer(_projectId) {
        Milestone storage milestone = projects[_projectId].milestones[_milestoneId];
        
        require(!milestone.completed, "Milestone already completed");
        require(!milestone.disputed, "Milestone is disputed");

        milestone.completed = true;

        emit MilestoneCompleted(_projectId, _milestoneId, msg.sender);
    }

    function approveMilestone(
        uint256 _projectId,
        uint256 _milestoneId
    ) external nonReentrant projectExists(_projectId) validMilestone(_projectId, _milestoneId) onlyClient(_projectId) {
        Milestone storage milestone = projects[_projectId].milestones[_milestoneId];
        Project storage project = projects[_projectId];
        
        require(milestone.completed, "Milestone not completed");
        require(!milestone.approved, "Milestone already approved");
        require(!milestone.disputed, "Cannot approve disputed milestone");

        milestone.approved = true;
        project.releasedAmount += milestone.amount;

        uint256 feeAmount = (milestone.amount * platformFee) / 10000;
        uint256 freelancerAmount = milestone.amount - feeAmount;

        if (feeAmount > 0) {
            project.token.safeTransfer(owner(), feeAmount);
        }
        project.token.safeTransfer(project.freelancer, freelancerAmount);

        emit MilestoneApproved(_projectId, _milestoneId, msg.sender, milestone.amount);
    }

    function disputeMilestone(
        uint256 _projectId,
        uint256 _milestoneId
    ) external projectExists(_projectId) validMilestone(_projectId, _milestoneId) onlyProjectParticipant(_projectId) {
        Milestone storage milestone = projects[_projectId].milestones[_milestoneId];
        
        require(milestone.completed, "Milestone not completed");
        require(!milestone.approved, "Cannot dispute approved milestone");
        require(!milestone.disputed, "Milestone already disputed");

        milestone.disputed = true;

        emit MilestoneDisputed(_projectId, _milestoneId, msg.sender);
    }

    function resolveDispute(
        uint256 _projectId,
        uint256 _milestoneId,
        bool _approveFreelancer
    ) external nonReentrant projectExists(_projectId) validMilestone(_projectId, _milestoneId) onlyOwner {
        Milestone storage milestone = projects[_projectId].milestones[_milestoneId];
        Project storage project = projects[_projectId];
        
        require(milestone.disputed, "Milestone not disputed");
        require(!milestone.approved, "Milestone already approved");

        milestone.disputed = false;

        if (_approveFreelancer) {
            milestone.approved = true;
            project.releasedAmount += milestone.amount;

            uint256 feeAmount = (milestone.amount * platformFee) / 10000;
            uint256 freelancerAmount = milestone.amount - feeAmount;

            if (feeAmount > 0) {
                project.token.safeTransfer(owner(), feeAmount);
            }
            project.token.safeTransfer(project.freelancer, freelancerAmount);
        }

        emit DisputeResolved(_projectId, _milestoneId, _approveFreelancer);
    }

    function cancelProject(
        uint256 _projectId
    ) external nonReentrant projectExists(_projectId) onlyClient(_projectId) {
        Project storage project = projects[_projectId];
        
        // Check that no milestones are completed but not yet approved/disputed
        for (uint256 i = 0; i < project.milestoneCount; i++) {
            Milestone storage milestone = project.milestones[i];
            require(
                !milestone.completed || milestone.approved || milestone.disputed,
                "Cannot cancel with pending milestones"
            );
        }

        uint256 refundAmount = project.totalAmount - project.releasedAmount;
        project.active = false;

        if (refundAmount > 0) {
            project.token.safeTransfer(project.client, refundAmount);
        }

        emit ProjectCancelled(_projectId);
    }

    function setPlatformFee(uint256 _newFee) external onlyOwner {
        require(_newFee <= MAX_FEE, "Fee too high");
        platformFee = _newFee;
    }

    function getProjectDetails(uint256 _projectId) external view returns (
        address client,
        address freelancer,
        address token,
        uint256 totalAmount,
        uint256 releasedAmount,
        uint256 milestoneCount,
        bool active
    ) {
        require(_projectId < projectCounter, "Project does not exist");
        Project storage project = projects[_projectId];
        return (
            project.client,
            project.freelancer,
            address(project.token),
            project.totalAmount,
            project.releasedAmount,
            project.milestoneCount,
            project.active
        );
    }

    function getMilestone(
        uint256 _projectId,
        uint256 _milestoneId
    ) external view returns (
        string memory description,
        uint256 amount,
        bool completed,
        bool approved,
        bool disputed
    ) {
        require(_projectId < projectCounter, "Project does not exist");
        require(_milestoneId < projects[_projectId].milestoneCount, "Invalid milestone");
        
        Milestone storage milestone = projects[_projectId].milestones[_milestoneId];
        return (
            milestone.description,
            milestone.amount,
            milestone.completed,
            milestone.approved,
            milestone.disputed
        );
    }
}