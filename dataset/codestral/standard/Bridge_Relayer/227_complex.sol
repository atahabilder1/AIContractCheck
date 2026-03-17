// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract DecentralizedRelayerNetwork {
    struct Relayer {
        address payable addr;
        uint256 stake;
        bool isActive;
    }

    mapping(address => Relayer) public relayers;
    uint256[] public activeRelayers;
    uint256 private currentIndex = 0;

    function stake(uint256 _amount) external {
        require(_amount > 0, "Stake amount must be greater than zero");
        Relayer memory relayer = relayers[msg.sender];
        if (relayer.isActive) return; // Already staked
        relayer.addr = payable(msg.sender);
        relayer.stake += _amount;
        relayer.isActive = true;
        activeRelayers.push(activeRelayers.length);
    }

    function unstake() external {
        Relayer memory relayer = relayers[msg.sender];
        require(relayer.isActive, "Not staked");
        relayer.isActive = false;
        activeRelayers[activeRelayers.length - 1] = activeRelayers[currentIndex];
        activeRelayers.pop();
        if (activeRelayers.length == currentIndex) currentIndex = 0;
    }

    function relayTransaction() external {
        Relayer memory relayer = relayers[msg.sender];
        require(relayer.isActive, "Not an active relayer");
        // Implement transaction relaying logic here
        reimburseRelayer();
    }

    function slashMaliciousRelayer(address _addr) external {
        Relayer memory relayer = relayers[_addr];
        require(relayer.isActive, "Not an active relayer");
        uint256 stakeToSlash = relayer.stake / 2; // Slashing half of the stake
        relayer.stake -= stakeToSlash;
    }

    function reimburseRelayer() private {
        address payable nextRelayerAddr = relayers[activeRelayers[currentIndex]].addr;
        uint256 gasPrice = _gasprice();
        uint256 gasUsed = gasleft();
        uint256 totalGasCost = gasPrice * gasUsed;
        nextRelayerAddr.transfer(totalGasCost);
    }
}