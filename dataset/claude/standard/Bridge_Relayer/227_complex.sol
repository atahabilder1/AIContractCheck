// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract RelayerNetwork {
    struct Relayer {
        uint256 stake;
        uint256 pendingRewards;
        bool active;
        uint256 slashCount;
        uint256 registeredAt;
    }

    struct RelayRequest {
        address sender;
        address target;
        bytes data;
        uint256 gasLimit;
        uint256 maxGasPrice;
        uint256 deadline;
        bool executed;
        address assignedRelayer;
        uint256 deposit;
    }

    address public owner;
    uint256 public minStake = 1 ether;
    uint256 public slashAmount = 0.5 ether;
    uint256 public maxSlashCount = 3;
    uint256 public relayerCount;
    uint256 public requestCount;
    uint256 public currentRelayerIndex;

    address[] public relayerList;
    mapping(address => Relayer) public relayers;
    mapping(uint256 => RelayRequest) public requests;
    mapping(address => uint256) public relayerIndexMap;

    event RelayerRegistered(address indexed relayer, uint256 stake);
    event RelayerUnregistered(address indexed relayer, uint256 stakeReturned);
    event RelayerSlashed(address indexed relayer, uint256 amount, string reason);
    event RelayRequested(uint256 indexed requestId, address indexed sender, address target, address assignedRelayer);
    event RelayExecuted(uint256 indexed requestId, address indexed relayer, bool success, uint256 gasReimbursed);
    event StakeAdded(address indexed relayer, uint256 amount);
    event RewardsWithdrawn(address indexed relayer, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier onlyActiveRelayer() {
        require(relayers[msg.sender].active, "Not active relayer");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function registerRelayer() external payable {
        require(!relayers[msg.sender].active, "Already registered");
        require(msg.value >= minStake, "Insufficient stake");

        relayers[msg.sender] = Relayer({
            stake: msg.value,
            pendingRewards: 0,
            active: true,
            slashCount: 0,
            registeredAt: block.timestamp
        });

        relayerIndexMap[msg.sender] = relayerList.length;
        relayerList.push(msg.sender);
        relayerCount++;

        emit RelayerRegistered(msg.sender, msg.value);
    }

    function addStake() external payable onlyActiveRelayer {
        require(msg.value > 0, "Zero value");
        relayers[msg.sender].stake += msg.value;
        emit StakeAdded(msg.sender, msg.value);
    }

    function unregisterRelayer() external onlyActiveRelayer {
        Relayer storage r = relayers[msg.sender];
        r.active = false;
        uint256 total = r.stake + r.pendingRewards;
        r.stake = 0;
        r.pendingRewards = 0;

        _removeRelayerFromList(msg.sender);
        relayerCount--;

        (bool sent, ) = msg.sender.call{value: total}("");
        require(sent, "Transfer failed");

        emit RelayerUnregistered(msg.sender, total);
    }

    function submitRelayRequest(
        address _target,
        bytes calldata _data,
        uint256 _gasLimit,
        uint256 _maxGasPrice,
        uint256 _deadline
    ) external payable returns (uint256) {
        require(relayerCount > 0, "No relayers available");
        require(_deadline > block.timestamp, "Deadline passed");
        require(msg.value > 0, "Deposit required for gas reimbursement");
        require(_target != address(0), "Invalid target");

        address assigned = _getNextRelayer();

        uint256 requestId = requestCount++;
        requests[requestId] = RelayRequest({
            sender: msg.sender,
            target: _target,
            data: _data,
            gasLimit: _gasLimit,
            maxGasPrice: _maxGasPrice,
            deadline: _deadline,
            executed: false,
            assignedRelayer: assigned,
            deposit: msg.value
        });

        emit RelayRequested(requestId, msg.sender, _target, assigned);
        return requestId;
    }

    function executeRelay(uint256 _requestId) external onlyActiveRelayer {
        RelayRequest storage req = requests[_requestId];
        require(!req.executed, "Already executed");
        require(msg.sender == req.assignedRelayer, "Not assigned relayer");
        require(block.timestamp <= req.deadline, "Deadline expired");
        require(tx.gasprice <= req.maxGasPrice, "Gas price too high");

        uint256 gasBefore = gasleft();

        req.executed = true;

        (bool success, ) = req.target.call{gas: req.gasLimit}(req.data);

        uint256 gasUsed = gasBefore - gasleft() + 30000; // overhead buffer
        uint256 reimbursement = gasUsed * tx.gasprice;

        if (reimbursement > req.deposit) {
            reimbursement = req.deposit;
        }

        relayers[msg.sender].pendingRewards += reimbursement;

        uint256 refund = req.deposit - reimbursement;
        if (refund > 0) {
            (bool refundSent, ) = req.sender.call{value: refund}("");
            require(refundSent, "Refund failed");
        }

        emit RelayExecuted(_requestId, msg.sender, success, reimbursement);
    }

    function slashRelayer(address _relayer, string calldata _reason) external onlyOwner {
        Relayer storage r = relayers[_relayer];
        require(r.active, "Not active");

        uint256 penalty = slashAmount;
        if (penalty > r.stake) {
            penalty = r.stake;
        }

        r.stake -= penalty;
        r.slashCount++;

        emit RelayerSlashed(_relayer, penalty, _reason);

        if (r.slashCount >= maxSlashCount || r.stake < minStake) {
            r.active = false;
            uint256 remaining = r.stake + r.pendingRewards;
            r.stake = 0;
            r.pendingRewards = 0;

            _removeRelayerFromList(_relayer);
            relayerCount--;

            if (remaining > 0) {
                (bool sent, ) = _relayer.call{value: remaining}("");
                require(sent, "Transfer failed");
            }
        }
    }

    function claimExpiredRequest(uint256 _requestId) external {
        RelayRequest storage req = requests[_requestId];
        require(!req.executed, "Already executed");
        require(block.timestamp > req.deadline, "Not expired");
        require(msg.sender == req.sender, "Not request sender");

        req.executed = true;
        uint256 deposit = req.deposit;
        req.deposit = 0;

        (bool sent, ) = msg.sender.call{value: deposit}("");
        require(sent, "Transfer failed");
    }

    function withdrawRewards() external onlyActiveRelayer {
        uint256 amount = relayers[msg.sender].pendingRewards;
        require(amount > 0, "No rewards");

        relayers[msg.sender].pendingRewards = 0;

        (bool sent, ) = msg.sender.call{value: amount}("");
        require(sent, "Transfer failed");

        emit RewardsWithdrawn(msg.sender, amount);
    }

    function setMinStake(uint256 _minStake) external onlyOwner {
        minStake = _minStake;
    }

    function setSlashAmount(uint256 _amount) external onlyOwner {
        slashAmount = _amount;
    }

    function setMaxSlashCount(uint256 _count) external onlyOwner {
        maxSlashCount = _count;
    }

    function getActiveRelayers() external view returns (address[] memory) {
        return relayerList;
    }

    function _getNextRelayer() internal returns (address) {
        require(relayerList.length > 0, "No relayers");

        uint256 startIndex = currentRelayerIndex % relayerList.length;
        uint256 idx = startIndex;

        do {
            address candidate = relayerList[idx];
            if (relayers[candidate].active) {
                currentRelayerIndex = (idx + 1) % relayerList.length;
                return candidate;
            }
            idx = (idx + 1) % relayerList.length;
        } while (idx != startIndex);

        revert("No active relayer found");
    }

    function _removeRelayerFromList(address _relayer) internal {
        uint256 index = relayerIndexMap[_relayer];
        uint256 lastIndex = relayerList.length - 1;

        if (index != lastIndex) {
            address lastRelayer = relayerList[lastIndex];
            relayerList[index] = lastRelayer;
            relayerIndexMap[lastRelayer] = index;
        }

        relayerList.pop();
        delete relayerIndexMap[_relayer];

        if (currentRelayerIndex >= relayerList.length && relayerList.length > 0) {
            currentRelayerIndex = 0;
        }
    }

    receive() external payable {}
}