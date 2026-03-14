// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IRelayer {
    function relay(address, bytes calldata) external;
}

contract DecentralizedRelayerNetwork {
    struct Relayer {
        address payable relayer;
        uint256 stake;
        bool active;
        uint256 nextRelayIndex;
    }

    IRelayer public immutable relayerRegistry;
    mapping(address => Relayer) public relayers;
    address[] public relayerList;

    uint256 public constant MIN_STAKE = 1 ether;
    uint256 public constant SLASH_FACTOR = 2;

    constructor(address _relayerRegistry) {
        relayerRegistry = IRelayer(_relayerRegistry);
    }

    function registerRelayer(uint256 stake) public payable {
        require(stake >= MIN_STAKE, "Minimum stake not met");
        relayers[msg.sender] = Relayer({
            relayer: payable(msg.sender),
            stake: stake,
            active: true,
            nextRelayIndex: relayerList.length
        });
        relayerList.push(msg.sender);
    }

    function unregisterRelayer() public {
        require(relayers[msg.sender].active, "Relayer not registered");
        require(relayers[msg.sender].stake == 0, "Relayer has stake, withdraw first");
        relayers[msg.sender].active = false;
        // Remove from relayer list
        uint256 index = relayers[msg.sender].nextRelayIndex;
        if (index != relayerList.length - 1) {
            relayerList[index] = relayerList[relayerList.length - 1];
            relayers[relayerList[index]].nextRelayIndex = index;
        }
        relayerList.pop();
    }

    function slashRelayer(address relayer, uint256 penalty) public {
        require(relayers[msg.sender].active, "Only active relayers can slash others");
        require(relayers[relayer].active, "Relayer not registered");
        require(penalty <= relayers[relayer].stake, "Penalty exceeds stake");
        relayers[relayer].stake -= penalty;
        relayers[msg.sender].stake += penalty / SLASH_FACTOR;
        relayers[msg.sender].stake -= penalty / SLASH_FACTOR;
    }

    function getNextRelayer() public view returns (address) {
        uint256 index = block.number % relayerList.length;
        return relayerList[index];
    }

    function relay(address target, bytes calldata data) public payable {
        address relayer = getNextRelayer();
        require(relayers[relayer].active, "Relayer not registered or penalized");
        relayerRegistry.relay(target, data);
        uint256 gasUsed = gasleft();
        uint256 gasReimbursement = gasUsed * tx.gasprice;
        require(msg.value >= gasReimbursement, "Not enough gas reimbursement");
        // Reimburse relayer
        (bool success, ) = relayer.call{value: gasReimbursement}("");
        require(success, "Relayer reimbursement failed");
    }
}