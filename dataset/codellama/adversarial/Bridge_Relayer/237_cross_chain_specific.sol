// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

contract BridgeRelayer {
    event NewSourceChainData(
        uint256 sourceChainId,
        address sourceContractAddress,
        bytes sourceData
    );

    mapping(uint256 => mapping(address => bytes)) public sourceChainData;

    function submitSourceChainData(
        uint256 sourceChainId,
        address sourceContractAddress,
        bytes calldata sourceData
    ) external {
        sourceChainData[sourceChainId][sourceContractAddress] = sourceData;
        emit NewSourceChainData(sourceChainId, sourceContractAddress, sourceData);
    }

    function getSourceChainData(
        uint256 sourceChainId,
        address sourceContractAddress
    ) external view returns (bytes memory) {
        return sourceChainData[sourceChainId][sourceContractAddress];
    }
}