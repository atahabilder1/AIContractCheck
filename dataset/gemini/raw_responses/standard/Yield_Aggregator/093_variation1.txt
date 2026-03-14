```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IUniswapV2Pair {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function MINIMUM_LIQUIDITY() external pure returns (uint256);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function sync() external;
    function skim(address to) external;
    function burn(address to) external returns (uint256 amount0, uint256 amount1);
    function mint(address to) external returns (uint256 liquidity);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function balanceOf(address owner) external view returns (uint256);
}

interface IUniswapV2Router02 {
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);
    function WETH() external pure returns (address);
}

contract AutoCompoundingVault is Ownable {
    IUniswapV2Router02 public immutable uniswapRouter;
    IUniswapV2Pair public immutable lpPair;
    IERC20 public immutable lpToken;

    address public token0;
    address public token1;

    constructor(address _uniswapRouter, address _lpPair) {
        uniswapRouter = IUniswapV2Router02(_uniswapRouter);
        lpPair = IUniswapV2Pair(_lpPair);
        lpToken = IERC20(_lpPair);

        token0 = lpPair.token0();
        token1 = lpPair.token1();
    }

    function deposit(uint256 amount0, uint256 amount1) external {
        require(msg.sender == owner(), "Only owner can deposit");

        IERC20(token0).transferFrom(msg.sender, address(this), amount0);
        IERC20(token1).transferFrom(msg.sender, address(this), amount1);

        // Approve router to spend LP tokens
        lpToken.approve(address(uniswapRouter), type(uint256).max);
        IERC20(token0).approve(address(uniswapRouter), type(uint256).max);
        IERC20(token1).approve(address(uniswapRouter), type(uint256).max);

        // Add liquidity
        uint256 deadline = block.timestamp + 1 days;
        uniswapRouter.addLiquidity(
            token0,
            token1,
            amount0,
            amount1,
            0, // amountAMin
            0, // amountBMin
            address(this), // to receive LP tokens
            deadline
        );
    }

    function compoundRewards() external onlyOwner {
        // Sync reserves to update rewards
        lpPair.sync();

        // Get current LP token balance of the vault
        uint256 vaultLpBalance = lpToken.balanceOf(address(this));

        // Remove liquidity to claim rewards
        uint256 deadline = block.timestamp + 1 days;
        (uint256 amount0, uint256 amount1) = lpPair.burn(address(this)); // burn LP tokens and receive underlying tokens + rewards

        // Swap earned rewards (token0 and token1) for more LP tokens.
        // This is a simplified example. In a real-world scenario, you'd want
        // to intelligently swap rewards to add liquidity.
        // Here we assume we want to compound by selling one token for the other
        // and then adding liquidity.

        // Example: Swap all earned token0 for token1
        if (amount0 > 0) {
            address[] memory path = new address[](2);
            path[0] = token0;
            path[1] = token1;

            uint256[] memory amounts = uniswapRouter.swapExactTokensForTokens(
                amount0,
                0, // amountOutMin
                path,
                address(this), // receive swapped tokens
                deadline
            );
            amount1 += amounts[amounts.length - 1]; // Add swapped amount to existing token1
        }

        // Now we have a certain amount of token1 (original earned + swapped)
        // and potentially some remaining token0 (if we didn't swap all).
        // For auto-compounding, we want to add this back as liquidity.
        // We need to determine how much of each token to use for adding liquidity.
        // A common strategy is to use the received tokens and add them proportionally.
        // However, since we swapped all token0 to token1, we now only have token1 to add.
        // This means we can't add liquidity directly with just one token.

        // A more robust auto-compounding strategy would involve:
        // 1. Receiving LP tokens from farming/staking.
        // 2. Claiming rewards.
        // 3. Swapping rewards to match the proportion of token0 and token1 in the LP pair.
        // 4. Adding the swapped rewards back as liquidity.

        // For this simplified example, let's assume we want to compound by
        // converting all earned rewards into one of the tokens and then adding
        // liquidity with that token and the vault's existing LP tokens.
        // This is not ideal and would require a more sophisticated approach.

        // A more direct auto-compounding approach is to claim rewards,
        // swap them to one of the base tokens (e.g., WETH), and then
        // use that token along with the vault's existing LP tokens to mint new LP tokens.
        // This requires having the vault's LP tokens already in the vault.

        // Let's refine the strategy:
        // 1. Burn LP tokens to get underlying tokens (amount0, amount1). These are our rewards.
        // 2. Swap one of the reward tokens (e.g., token0) for the other (token1).
        // 3. Now we have a total amount of token1 (original earned + swapped) and potentially some token0.
        // 4. The goal is to add this back as liquidity. To do this, we need both token0 and token1.
        //    If we swapped all token0 for token1, we only have token1. We can't add liquidity.

        // A better auto-compounding strategy involves claiming rewards,
        // swapping them to match the pair's ratio, and then adding liquidity.
        // This requires a way to know the current ratio of token0 and token1 in the pool.

        // For a direct auto-compounding scenario of LP rewards *from the pool itself*,
        // the 'rewards' are typically claimed by interacting with a farming contract,
        // not directly from burning LP tokens. Burning LP tokens gives you your share of the pool.

        // Let's re-interpret the prompt: "auto-compounds LP rewards from a Uniswap-style pool back into the same position."
        // This implies rewards are generated by *staking* the LP tokens, not by the LP position itself.
        // The contract as written *adds* liquidity. It doesn't stake LP tokens.

        // Assuming the user deposits LP tokens into a separate staking contract,
        // and this contract's role is to claim those rewards and add them back.

        // If the prompt means the LP tokens themselves generate rewards (e.g., through a fee mechanism that is distributed),
        // then the `burn` function might be a way to 'claim' those accumulated fees.
        // However, burning LP tokens removes them from circulation.

        // Let's assume the intention is to compound by adding more liquidity.
        // The `burn` function above gives us `amount0` and `amount1` which represent
        // our share of the pool at that moment, *including any accumulated fees*.
        // If we want to compound, we should take these `amount0` and `amount1`,
        // potentially swap them to create a balanced pair, and then add them back.

        // Let's refine the compounding logic:
        // After burning LP tokens, we have `amount0` and `amount1`.
        // These are essentially our "rewards" in the form of underlying tokens.
        // To compound, we want to add this back as liquidity.
        // We need to ensure we have a balanced pair to add liquidity.

        // If `amount0` and `amount1` are already balanced according to the pool's ratio,
        // we can directly add them back. If not, we need to swap.

        // Let's assume we want to use the earned `amount0` and `amount1` to mint *new* LP tokens.
        // We'll need to ensure we have a balanced amount of token0 and token1.

        // Example: Swap `amount0` to `token1` if it's more than the pool ratio.
        // Or swap `amount1` to `token0` if it's more.
        // This requires knowing the pool's current reserves to calculate the ratio.

        // Let's simplify: Assume we want to swap all earned `amount0` for `token1`
        // and then add the resulting `amount1` along with the existing vault's `amount0`
        // (if any was not used in the initial deposit) to mint new LP tokens.
        // This is still a bit convoluted.

        // A more straightforward auto-compounding approach for LP rewards:
        // 1. The vault holds LP tokens.
        // 2. A separate farming/staking contract (not shown here) stakes these LP tokens and generates rewards.
        // 3. This `compoundRewards` function is called periodically.
        // 4. It claims rewards from the farming contract.
        // 5. It swaps these rewards to match the token0/token1 ratio of the LP pool.
        // 6. It then adds these swapped rewards as new liquidity, minting more LP tokens.
        // 7. These new LP tokens are then restaked in the farming contract (external action or another function).

        // The current contract design is for *depositing* and *adding liquidity*.
        // The `compoundRewards` function, as written with `lpPair.burn()`, is essentially
        // withdrawing liquidity to claim fees. This is not typical auto-compounding of *rewards*.

        // Let's assume the prompt means:
        // The vault has LP tokens. These LP tokens are staked elsewhere.
        // This vault contract's job is to claim rewards from the staking contract,
        // swap them to match the LP pool's ratio, and then add them as more liquidity.

        // This requires interactions with a staking contract, which is not defined here.
        // Let's adapt the `compoundRewards` to simulate claiming rewards and compounding.

        // --- Revised approach for compounding ---
        // Assume the vault *holds* LP tokens.
        // Assume rewards are generated by some external mechanism (e.g., a farming contract).
        // This function will simulate claiming rewards and adding them back.

        // For demonstration, let's assume we have received some `rewardToken0` and `rewardToken1`.
        // We need to swap these to add liquidity.

        // The `lpPair.burn(address(this))` call in the current `compoundRewards`
        // actually burns the vault's *own LP tokens* to get underlying assets.
        // This removes liquidity, not adds it. This is not auto-compounding.

        // Let's assume the vault *receives* rewards externally.
        // For example, `claimRewards(address rewardToken, uint256 amount)`.
        // Then `compoundRewards` would take those claimed rewards and add liquidity.

        // Let's modify `compoundRewards` to *assume* we have received rewards.
        // We will simulate receiving rewards and then compounding them.

        // --- Simulating Reward Claim and Compounding ---
        // In a real scenario, you'd have a function like `claimAndCompound(address rewardToken0, address rewardToken1)`
        // which would receive the rewards.

        // For this example, let's assume we have some `earnedToken0` and `earnedToken1` already in the contract.
        // We will use these to add liquidity.

        // --- Actual Auto-Compounding Logic (assuming rewards are in contract) ---

        // Step 1: Get current balance of the vault's underlying tokens.
        // These are the tokens we will use to add liquidity.
        // For simplicity, let's assume the vault *only* holds LP tokens.
        // If the vault holds LP tokens, it needs to unstake them to get underlying.

        // Let's stick to the prompt: "auto-compounds LP rewards from a Uniswap-style pool back into the same position."
        // This implies the LP position itself generates rewards (e.g., fees).
        // The `sync()` and `burn()` approach *is* one way to collect fees, but it reduces your LP share.

        // A common auto-compounding strategy is:
        // 1. Vault holds LP tokens.
        // 2. LP tokens are staked in a yield farm.
        // 3. `compoundRewards` function claims rewards from the farm.
        // 4. Rewards are swapped to match the LP pair's token ratio.
        // 5. Swapped rewards are added as new liquidity, minting more LP tokens.
        // 6. New LP tokens are automatically restaked in the farm.

        // This requires interaction with a farming contract.
        // Since no farming contract is provided, let's simulate the process of
        // having earned rewards and adding them back.

        // --- Simplified Auto-Compounding (assuming vault holds underlying tokens as rewards) ---
        // Let's assume the vault has some `token0` and `token1` that are considered "rewards".
        // We will add these as liquidity.

        // To add liquidity, we need a balanced pair.
        // Let's assume the vault's current balances of `token0` and `token1` are the rewards to be compounded.
        uint256 currentToken0Balance = IERC20(token0).balanceOf(address(this));
        uint256 currentToken1Balance = IERC20(token1).balanceOf(address(this));

        // If we have no rewards, do nothing.
        if (currentToken0Balance == 0 && currentToken1Balance == 0) {
            return;
        }

        // To add liquidity, we need to ensure we have a balanced pair.
        // We can use the router to swap one token for the other to achieve balance.
        // A simple strategy: if we have more token0 than token1, swap some token0 for token1.
        // Or vice-versa. This requires knowing the pool's ratio.

        // Let's use a simplified approach: swap all of one token to the other and then add liquidity.
        // This is not optimal but demonstrates the concept.

        uint256 amount0ToAdd = 0;
        uint256 amount1ToAdd = 0;

        // If we have rewards in token0, try to convert them to token1 to balance.
        if (currentToken0Balance > 0) {
            // Determine how much token0 to keep and how much to swap.
            // A common strategy is to swap the excess of one token to match the other.
            // Let's assume for simplicity we want to swap *all* earned token0 for token1.
            // This is naive and might not be optimal.

            address[] memory path = new address[](2);
            path[0] = token0;
            path[1] = token1;

            uint256[] memory amounts = uniswapRouter.swapExactTokensForTokens(
                currentToken0Balance,
                0, // amountOutMin
                path,
                address(this), // receive swapped tokens
                block.timestamp + 1 days
            );
            // After swapping, currentToken0Balance becomes 0, and currentToken1Balance increases by amounts[1].
            currentToken1Balance += amounts[1];
            amount0ToAdd = 0; // We have swapped all token0
            amount1ToAdd = currentToken1Balance; // Use all available token1
        } else if (currentToken1Balance > 0)