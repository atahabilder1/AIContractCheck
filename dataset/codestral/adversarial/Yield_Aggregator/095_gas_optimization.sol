// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract YieldAggregator {
    uint256 public totalYield;

    struct PoolInfo {
        IERC20 token;
        address poolAddress;
        uint256 lastYield;
    }

    mapping(address => PoolInfo) private pools;

    constructor() {}

    function addPool(address _pool, IERC20 _token, address _tokenAddress) public {
        require(_token.balanceOf(_pool) > 0, "No tokens in the pool");
        totalYield += _token.balanceOf(_pool);
        PoolInfo memory newPool = PoolInfo(_token, _pool, _token.balanceOf(_pool));
        pools[_tokenAddress] = newPool;
    }

    function updateTotalYield() public {
        uint256 currentYield = 0;
        for (address tokenAddress in pools) {
            PoolInfo memory pool = pools[tokenAddress];
            currentYield += pool.token.balanceOf(pool.poolAddress);
            totalYield -= pool.lastYield;
            pool.lastYield = pool.token.balanceOf(pool.poolAddress);
        }
        totalYield += currentYield;
    }
}