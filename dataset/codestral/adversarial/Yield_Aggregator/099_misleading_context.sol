// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract YieldAggregator {
    struct YieldSource {
        address sourceAddress;
        uint256 yieldPercentage;
    }

    mapping(address => YieldSource) public sources;
    uint256 public totalYieldPercentage;

    function addSource(address _sourceAddress, uint256 _yieldPercentage) external {
        require(_yieldPercentage <= 100, "Invalid yield percentage");
        require(totalYieldPercentage + _yieldPercentage <= 100, "Total yield percentage exceeds 100%");

        sources[_sourceAddress] = YieldSource(_sourceAddress, _yieldPercentage);
        totalYieldPercentage += _yieldPercentage;
    }

    function removeSource(address _sourceAddress) external {
        require(sources[_sourceAddress].yieldPercentage > 0, "Source not found");

        totalYieldPercentage -= sources[_sourceAddress].yieldPercentage;
        delete sources[_sourceAddress];
    }

    function updateSource(address _sourceAddress, uint256 _newYieldPercentage) external {
        require(_newYieldPercentage <= 100, "Invalid yield percentage");
        YieldSource memory source = sources[_sourceAddress];
        require(source.yieldPercentage > 0, "Source not found");

        totalYieldPercentage -= source.yieldPercentage;
        source.yieldPercentage = _newYieldPercentage;
        sources[_sourceAddress] = source;
        totalYieldPercentage += _newYieldPercentage;
    }
}