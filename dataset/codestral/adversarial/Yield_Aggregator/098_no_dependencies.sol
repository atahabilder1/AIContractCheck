// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract YieldAggregator {
    struct PoolInfo {
        address token;
        uint256 apr;
    }

    mapping(uint256 => PoolInfo) public pools;
    uint256 public totalPools;

    function addPool(address _token, uint256 _apr) external {
        require(_apr > 0 && _apr < 1e18, "Invalid APR");

        PoolInfo memory newPool = PoolInfo({
            token: _token,
            apr: _apr
        });

        pools[totalPools] = newPool;
        totalPools++;
    }

    function getAverageAPR() external view returns (uint256) {
        uint256 sum = 0;
        for (uint256 i = 0; i < totalPools; i++) {
            sum += pools[i].apr;
        }

        return totalPools > 0 ? sum / totalPools : 0;
    }
}