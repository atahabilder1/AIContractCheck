// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract ConstantProductAMM {
    IERC20 public token0;
    IERC20 public token1;

    uint256 public k; // The constant product invariant

    mapping(address => uint256) public reserves0;
    mapping(address => uint256) public reserves1;

    constructor(address _token0, address _token1) {
        token0 = IERC20(_token0);
        token1 = IERC20(_token1);
    }

    // Function to add liquidity
    function addLiquidity(uint256 amount0Desired, uint256 amount1Desired) public {
        require(amount0Desired > 0 || amount1Desired > 0, "Must provide amounts");

        uint256 balance0 = token0.balanceOf(msg.sender);
        uint256 balance1 = token1.balanceOf(msg.sender);

        uint256 amount0;
        uint256 amount1;

        if (k == 0) {
            // First liquidity addition
            amount0 = amount0Desired;
            amount1 = amount1Desired;
            require(amount0 > 0 && amount1 > 0, "Initial liquidity must be non-zero for both tokens");
            k = amount0 * amount1;
        } else {
            // Subsequent liquidity additions
            if (amount0Desired == 0) {
                amount1 = amount1Desired;
                amount0 = (k * amount1) / reserves1[address(this)];
            } else if (amount1Desired == 0) {
                amount0 = amount0Desired;
                amount1 = (k * amount0) / reserves0[address(this)];
            } else {
                // Calculate amounts based on current reserves and desired amounts to maintain ratio
                uint256 amount0Optimal = (k * amount1Desired) / reserves1[address(this)];
                uint256 amount1Optimal = (k * amount0Desired) / reserves0[address(this)];

                if (amount0Optimal <= amount0Desired) {
                    amount0 = amount0Optimal;
                    amount1 = amount1Desired;
                } else {
                    amount1 = amount1Optimal;
                    amount0 = amount0Desired;
                }
            }
            require(amount0 <= balance0, "Insufficient token0 balance");
            require(amount1 <= balance1, "Insufficient token1 balance");
            k = (reserves0[address(this)] + amount0) * (reserves1[address(this)] + amount1);
        }

        token0.transferFrom(msg.sender, address(this), amount0);
        token1.transferFrom(msg.sender, address(this), amount1);

        reserves0[msg.sender] += amount0;
        reserves1[msg.sender] += amount1;
    }

    // Function to remove liquidity
    function removeLiquidity(uint256 amount0ToRemove, uint256 amount1ToRemove) public {
        require(amount0ToRemove > 0 || amount1ToRemove > 0, "Must provide amounts");
        require(amount0ToRemove <= reserves0[msg.sender], "Insufficient liquidity to remove");
        require(amount1ToRemove <= reserves1[msg.sender], "Insufficient liquidity to remove");

        // Update k based on remaining liquidity
        k = (reserves0[address(this)] - amount0ToRemove) * (reserves1[address(this)] - amount1ToRemove);

        reserves0[msg.sender] -= amount0ToRemove;
        reserves1[msg.sender] -= amount1ToRemove;

        token0.transfer(msg.sender, amount0ToRemove);
        token1.transfer(msg.sender, amount1ToRemove);
    }

    // Function to swap token0 for token1
    function swap0for1(uint256 amount0In) public returns (uint256 amount1Out) {
        require(amount0In > 0, "Must provide amount");
        require(amount0In <= token0.balanceOf(msg.sender), "Insufficient token0 balance");

        uint256 reserve0 = reserves0[address(this)];
        uint256 reserve1 = reserves1[address(this)];

        require(reserve0 > 0 && reserve1 > 0, "Pool is empty");

        amount1Out = (reserve1 * amount0In) / (reserve0 + amount0In);
        require(amount1Out > 0, "Swap too small");

        // Update k (which is implicitly done by updating reserves)
        k = (reserve0 + amount0In) * (reserve1 - amount1Out);

        token0.transferFrom(msg.sender, address(this), amount0In);
        reserves0[address(this)] += amount0In;
        reserves1[address(this)] -= amount1Out;

        token1.transfer(msg.sender, amount1Out);
    }

    // Function to swap token1 for token0
    function swap1for0(uint256 amount1In) public returns (uint256 amount0Out) {
        require(amount1In > 0, "Must provide amount");
        require(amount1In <= token1.balanceOf(msg.sender), "Insufficient token1 balance");

        uint256 reserve0 = reserves0[address(this)];
        uint256 reserve1 = reserves1[address(this)];

        require(reserve0 > 0 && reserve1 > 0, "Pool is empty");

        amount0Out = (reserve0 * amount1In) / (reserve1 + amount1In);
        require(amount0Out > 0, "Swap too small");

        // Update k (which is implicitly done by updating reserves)
        k = (reserve0 - amount0Out) * (reserve1 + amount1In);

        token1.transferFrom(msg.sender, address(this), amount1In);
        reserves1[address(this)] += amount1In;
        reserves0[address(this)] -= amount0Out;

        token0.transfer(msg.sender, amount0Out);
    }

    // Helper to get current reserves of the pool
    function getReserves() public view returns (uint256 _reserve0, uint256 _reserve1) {
        return (reserves0[address(this)], reserves1[address(this)]);
    }
}

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
}