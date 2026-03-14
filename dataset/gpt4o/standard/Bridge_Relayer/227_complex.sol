// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract DecentralizedRelayerNetwork {
    struct Relayer {
        uint256 stake;
        bool active;
        uint256 lastAssignedRound;
    }

    mapping(address => Relayer) public relayers;
    address[] public relayerList;
    uint256 public totalStaked;
    uint256 public roundRobinIndex;

    uint256 public constant MINIMUM_STAKE = 1 ether;
    uint256 public constant SLASHING_AMOUNT = 0.1 ether;

    event RelayerRegistered(address indexed relayer, uint256 stake);
    event RelayerUnregistered(address indexed relayer);
    event StakeIncreased(address indexed relayer, uint256 newStake);
    event Slashed(address indexed relayer, uint256 amount);
    event RelayAssigned(address indexed relayer, address indexed task);
    event GasReimbursed(address indexed relayer, uint256 amount);

    modifier onlyActiveRelayer() {
        require(relayers[msg.sender].active, "Not an active relayer");
        _;
    }

    function registerRelayer() external payable {
        require(msg.value >= MINIMUM_STAKE, "Insufficient stake");
        require(!relayers[msg.sender].active, "Already registered");

        relayers[msg.sender] = Relayer({
            stake: msg.value,
            active: true,
            lastAssignedRound: 0
        });
        relayerList.push(msg.sender);
        totalStaked += msg.value;

        emit RelayerRegistered(msg.sender, msg.value);
    }

    function unregisterRelayer() external onlyActiveRelayer {
        require(relayers[msg.sender].stake >= MINIMUM_STAKE, "Insufficient stake to unregister");

        payable(msg.sender).transfer(relayers[msg.sender].stake);
        totalStaked -= relayers[msg.sender].stake;

        relayers[msg.sender].active = false;
        relayers[msg.sender].stake = 0;

        emit RelayerUnregistered(msg.sender);
    }

    function increaseStake() external payable onlyActiveRelayer {
        relayers[msg.sender].stake += msg.value;
        totalStaked += msg.value;

        emit StakeIncreased(msg.sender, relayers[msg.sender].stake);
    }

    function slashRelayer(address _relayer) external {
        require(relayers[_relayer].active, "Relayer is not active");
        require(relayers[_relayer].stake >= SLASHING_AMOUNT, "Insufficient stake to slash");

        relayers[_relayer].stake -= SLASHING_AMOUNT;
        totalStaked -= SLASHING_AMOUNT;

        emit Slashed(_relayer, SLASHING_AMOUNT);
    }

    function assignRelay(address _task) external {
        require(relayerList.length > 0, "No relayers available");

        address relayer = relayerList[roundRobinIndex];
        roundRobinIndex = (roundRobinIndex + 1) % relayerList.length;

        emit RelayAssigned(relayer, _task);
    }

    function reimburseGas(address _relayer, uint256 _amount) external {
        require(relayers[_relayer].active, "Relayer is not active");
        require(address(this).balance >= _amount, "Insufficient balance for reimbursement");

        payable(_relayer).transfer(_amount);

        emit GasReimbursed(_relayer, _amount);
    }

    receive() external payable {}
}