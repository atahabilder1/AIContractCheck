// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract YieldAggregator {
    struct YieldAggregatorData {
        address owner;
        uint256[] tokenIds;
        uint256[] tokenPrices;
    }

    mapping(address => YieldAggregatorData) private _data;

    event YieldAggregatorUpdated(address indexed owner, uint256[] tokenIds, uint256[] tokenPrices);

    function updateYieldAggregator(uint256[] memory tokenIds, uint256[] memory tokenPrices) public {
        require(tokenIds.length == tokenPrices.length, "Invalid input");

        YieldAggregatorData storage data = _data[msg.sender];
        data.tokenIds = tokenIds;
        data.tokenPrices = tokenPrices;

        emit YieldAggregatorUpdated(msg.sender, tokenIds, tokenPrices);
    }

    function getYieldAggregatorData(address owner) public view returns (YieldAggregatorData memory) {
        return _data[owner];
    }
}