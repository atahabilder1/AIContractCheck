// Source: Etherscan Verified Contract
// Address: 0xba1333333333a1ba1108e8412f11850a5c319ba9
// Name: Vault
// Compiler: v0.8.26+commit.8a97fa7a
// License: 
// Collected: 2026-03-16T17:55:28.275972

// File: @balancer-labs/v3-interfaces/contracts/solidity-utils/helpers/IAuthentication.sol

// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.24;

/// @notice Simple interface for permissioned calling of external functions.
interface IAuthentication {
    /// @notice The sender does not have permission to call a function.
    error SenderNotAllowed();

    /**
     * @notice Returns the action identifier associated with the external function described by `selector`.
     * @param selector The 4-byte selector of the permissioned function
     * @return actionId The computed actionId
     */
    function getActionId(bytes4 selector) external view returns (bytes32 actionId);
}


// File: @balancer-labs/v3-interfaces/contracts/solidity-utils/helpers/IRateProvider.sol

// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.24;

/// @notice General interface for token exchange rates.
interface IRateProvider {
    /**
     * @notice An 18 decimal fixed point number representing the exchange rate of one token to another related token.
     * @dev The meaning of this rate depends on the context. Note that there may be an error associated with a token
     * rate, and the caller might require a certain rounding direction to ensure correctness. This (legacy) interface
     * does not take a rounding direction or return an error, so great care must be taken when interpreting and using
     * rates in downstream computations.
     *
     * @return rate The current token rate
     */
    function getRate() external view returns (uint256 rate);
}


// File: @balancer-labs/v3-interfaces/contracts/vault/IAuthorizer.sol

// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.24;

/// @notice Interface to the Vault's permission system.
interface IAuthorizer {
    /**
     * @notice Returns true if `account` can perform the action described by `actionId` in the contract `where`.
     * @param actionId Identifier for the action to be performed
     * @param account Account trying to perform the action
     * @param where Target contract for the action
     * @return success True if the action is permitted
     */
    function canPerform(bytes32 actionId, address account, address where) external view returns (bool success);
}


// File: @balancer-labs/v3-interfaces/contracts/vault/IBasePool.sol

// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.24;

import { IUnbalancedLiquidityInvariantRatioBounds } from "./IUnbalancedLiquidityInvariantRatioBounds.sol";
import { ISwapFeePercentageBounds } from "./ISwapFeePercentageBounds.sol";
import { PoolSwapParams, Rounding, SwapKind } from "./VaultTypes.sol";

/**
 * @notice Base interface for a Balancer Pool.
 * @dev All pool types should implement this interface. Note that it also requires implementation of:
 * - `ISwapFeePercentageBounds` to specify the minimum and maximum swap fee percentages.
 * - `IUnbalancedLiquidityInvariantRatioBounds` to specify how much the invariant can change during an unbalanced
 * liquidity operation.
 */
interface IBasePool is ISwapFeePercentageBounds, IUnbalancedLiquidityInvariantRatioBounds {
    /***************************************************************************
                                   Invariant
    ***************************************************************************/

    /**
     * @notice Computes the pool's invariant.
     * @dev This function computes the invariant based on current balances (and potentially other pool state).
     * The rounding direction must be respected for the Vault to round in the pool's favor when calling this function.
     * If the invariant computation involves no precision loss (e.g. simple sum of balances), the same result can be
     * returned for both rounding directions.
     *
     * You can think of the invariant as a measure of the "value" of the pool, which is related to the total liquidity
     * (i.e., the "BPT rate" is `invariant` / `totalSupply`). Two critical properties must hold:
     *
     * 1) The invariant should not change due to a swap. In practice, it can *increase* due to swap fees, which
     * effectively add liquidity after the swap - but it should never decrease.
     *
     * 2) The invariant must be "linear"; i.e., increasing the balances proportionally must increase the invariant in
     * the same proportion: inv(a * n, b * n, c * n) = inv(a, b, c) * n
     *
     * Property #1 is required to prevent "round trip" paths that drain value from the pool (and all LP shareholders).
     * Intuitively, an accurate pricing algorithm ensures the user gets an equal value of token out given token in, so
     * the total value should not change.
     *
     * Property #2 is essential for the "fungibility" of LP shares. If it did not hold, then different users depositing
     * the same total value would get a different number of LP shares. In that case, LP shares would not be
     * interchangeable, as they must be in a fair DEX.
     *
     * @param balancesLiveScaled18 Token balances after paying yield fees, applying decimal scaling and rates
     * @param rounding Rounding direction to consider when computing the invariant
     * @return invariant The calculated invariant of the pool, represented as a uint256
     */
    function computeInvariant(
        uint256[] memory balancesLiveScaled18,
        Rounding rounding
    ) external view returns (uint256 invariant);

    /**
     * @notice Computes a new token balance, given the invariant growth ratio and all other balances.
     * @dev Similar to V2's `_getTokenBalanceGivenInvariantAndAllOtherBalances` in StableMath.
     * The pool must round up for the Vault to round in the protocol's favor when calling this function.
     *
     * @param balancesLiveScaled18 Token balances after paying yield fees, applying decimal scaling and rates
     * @param tokenInIndex The index of the token we're computing the balance for, sorted in token registration order
     * @param invariantRatio The ratio of the new invariant (after an operation) to the old
     * @return newBalance The new balance of the selected token, after the operation
     */
    function computeBalance(
        uint256[] memory balancesLiveScaled18,
        uint256 tokenInIndex,
        uint256 invariantRatio
    ) external view returns (uint256 newBalance);

    /***************************************************************************
                                       Swaps
    ***************************************************************************/

    /**
     * @notice Execute a swap in the pool.
     * @param params Swap parameters (see above for struct definition)
     * @return amountCalculatedScaled18 Calculated amount for the swap operation
     */
    function onSwap(PoolSwapParams calldata params) external returns (uint256 amountCalculatedScaled18);
}


// File: @balancer-labs/v3-interfaces/contracts/vault/IERC20MultiTokenErrors.sol

// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.24;

interface IERC20MultiTokenErrors {
    /**
     * @notice The total supply of a pool token can't be lower than the absolute minimum.
     * @param totalSupply The total supply value that was below the minimum
     */
    error PoolTotalSupplyTooLow(uint256 totalSupply);
}


// File: @balancer-labs/v3-interfaces/contracts/vault/IHooks.sol

// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.24;

// Explicitly import VaultTypes structs because we expect this interface to be heavily used by external developers.
// Internally, when this list gets too long, we usually just do a simple import to keep things tidy.
import {
    TokenConfig,
    LiquidityManagement,
    PoolSwapParams,
    AfterSwapParams,
    HookFlags,
    AddLiquidityKind,
    RemoveLiquidityKind,
    SwapKind
} from "./VaultTypes.sol";

/**
 * @notice Interface for pool hooks.
 * @dev Hooks are functions invoked by the Vault at specific points in the flow of each operation. This guarantees that
 * they are called in the correct order, and with the correct arguments. To maintain this security, these functions
 * should only be called by the Vault. The recommended way to do this is to derive the hook contract from `BaseHooks`,
 * then use the `onlyVault` modifier from `VaultGuard`. (See the examples in /pool-hooks.)
 */
interface IHooks {
    /***************************************************************************
                                   Register
    ***************************************************************************/

    /**
     * @notice Hook executed when a pool is registered with a non-zero hooks contract.
     * @dev Returns true if registration was successful, and false to revert the pool registration.
     * Make sure this function is properly implemented (e.g. check the factory, and check that the
     * given pool is from the factory). The Vault address will be msg.sender.
     *
     * @param factory Address of the pool factory (contract deploying the pool)
     * @param pool Address of the pool
     * @param tokenConfig An array of descriptors for the tokens the pool will manage
     * @param liquidityManagement Liquidity management flags indicating which functions are enabled
     * @return success True if the hook allowed the registration, false otherwise
     */
    function onRegister(
        address factory,
        address pool,
        TokenConfig[] memory tokenConfig,
        LiquidityManagement calldata liquidityManagement
    ) external returns (bool success);

    /**
     * @notice Return the set of hooks implemented by the contract.
     * @dev The Vault will only call hooks the pool says it supports, and of course only if a hooks contract is defined
     * (i.e., the `poolHooksContract` in `PoolRegistrationParams` is non-zero).
     * `onRegister` is the only "mandatory" hook.
     *
     * @return hookFlags Flags indicating which hooks the contract supports
     */
    function getHookFlags() external view returns (HookFlags memory hookFlags);

    /***************************************************************************
                                   Initialize
    ***************************************************************************/

    /**
     * @notice Hook executed before pool initialization.
     * @dev Called if the `shouldCallBeforeInitialize` flag is set in the configuration. Hook contracts should use
     * the `onlyVault` modifier to guarantee this is only called by the Vault.
     *
     * @param exactAmountsIn Exact amounts of input tokens
     * @param userData Optional, arbitrary data sent with the encoded request
     * @return success True if the pool wishes to proceed with initialization
     */
    function onBeforeInitialize(uint256[] memory exactAmountsIn, bytes memory userData) external returns (bool success);

    /**
     * @notice Hook to be executed after pool initialization.
     * @dev Called if the `shouldCallAfterInitialize` flag is set in the configuration. Hook contracts should use
     * the `onlyVault` modifier to guarantee this is only called by the Vault.
     *
     * @param exactAmountsIn Exact amounts of input tokens
     * @param bptAmountOut Amount of pool tokens minted during initialization
     * @param userData Optional, arbitrary data sent with the encoded request
     * @return success True if the pool accepts the initialization results
     */
    function onAfterInitialize(
        uint256[] memory exactAmountsIn,
        uint256 bptAmountOut,
        bytes memory userData
    ) external returns (bool success);

    /***************************************************************************
                                   Add Liquidity
    ***************************************************************************/

    /**
     * @notice Hook to be executed before adding liquidity.
     * @dev Called if the `shouldCallBeforeAddLiquidity` flag is set in the configuration. Hook contracts should use
     * the `onlyVault` modifier to guarantee this is only called by the Vault.
     *
     * @param router The address (usually a router contract) that initiated an add liquidity operation on the Vault
     * @param pool Pool address, used to fetch pool information from the Vault (pool config, tokens, etc.)
     * @param kind The add liquidity operation type (e.g., proportional, custom)
     * @param maxAmountsInScaled18 Maximum amounts of input tokens
     * @param minBptAmountOut Minimum amount of output pool tokens
     * @param balancesScaled18 Current pool balances, sorted in token registration order
     * @param userData Optional, arbitrary data sent with the encoded request
     * @return success True if the pool wishes to proceed with settlement
     */
    function onBeforeAddLiquidity(
        address router,
        address pool,
        AddLiquidityKind kind,
        uint256[] memory maxAmountsInScaled18,
        uint256 minBptAmountOut,
        uint256[] memory balancesScaled18,
        bytes memory userData
    ) external returns (bool success);

    /**
     * @notice Hook to be executed after adding liquidity.
     * @dev Called if the `shouldCallAfterAddLiquidity` flag is set in the configuration. The Vault will ignore
     * `hookAdjustedAmountsInRaw` unless `enableHookAdjustedAmounts` is true. Hook contracts should use the
     * `onlyVault` modifier to guarantee this is only called by the Vault.
     *
     * @param router The address (usually a router contract) that initiated an add liquidity operation on the Vault
     * @param pool Pool address, used to fetch pool information from the Vault (pool config, tokens, etc.)
     * @param kind The add liquidity operation type (e.g., proportional, custom)
     * @param amountsInScaled18 Actual amounts of tokens added, sorted in token registration order
     * @param amountsInRaw Actual amounts of tokens added, sorted in token registration order
     * @param bptAmountOut Amount of pool tokens minted
     * @param balancesScaled18 Current pool balances, sorted in token registration order
     * @param userData Additional (optional) data provided by the user
     * @return success True if the pool wishes to proceed with settlement
     * @return hookAdjustedAmountsInRaw New amountsInRaw, potentially modified by the hook
     */
    function onAfterAddLiquidity(
        address router,
        address pool,
        AddLiquidityKind kind,
        uint256[] memory amountsInScaled18,
        uint256[] memory amountsInRaw,
        uint256 bptAmountOut,
        uint256[] memory balancesScaled18,
        bytes memory userData
    ) external returns (bool success, uint256[] memory hookAdjustedAmountsInRaw);

    /***************************************************************************
                                 Remove Liquidity
    ***************************************************************************/

    /**
     * @notice Hook to be executed before removing liquidity.
     * @dev Called if the `shouldCallBeforeRemoveLiquidity` flag is set in the configuration. Hook contracts should use
     * the `onlyVault` modifier to guarantee this is only called by the Vault.
     *
     * @param router The address (usually a router contract) that initiated a remove liquidity operation on the Vault
     * @param pool Pool address, used to fetch pool information from the Vault (pool config, tokens, etc.)
     * @param kind The type of remove liquidity operation (e.g., proportional, custom)
     * @param maxBptAmountIn Maximum amount of input pool tokens
     * @param minAmountsOutScaled18 Minimum output amounts, sorted in token registration order
     * @param balancesScaled18 Current pool balances, sorted in token registration order
     * @param userData Optional, arbitrary data sent with the encoded request
     * @return success True if the pool wishes to proceed with settlement
     */
    function onBeforeRemoveLiquidity(
        address router,
        address pool,
        RemoveLiquidityKind kind,
        uint256 maxBptAmountIn,
        uint256[] memory minAmountsOutScaled18,
        uint256[] memory balancesScaled18,
        bytes memory userData
    ) external returns (bool success);

    /**
     * @notice Hook to be executed after removing liquidity.
     * @dev Called if the `shouldCallAfterRemoveLiquidity` flag is set in the configuration. The Vault will ignore
     * `hookAdjustedAmountsOutRaw` unless `enableHookAdjustedAmounts` is true. Hook contracts should use the
     * `onlyVault` modifier to guarantee this is only called by the Vault.
     *
     * @param router The address (usually a router contract) that initiated a remove liquidity operation on the Vault
     * @param pool Pool address, used to fetch pool information from the Vault (pool config, tokens, etc.)
     * @param kind The type of remove liquidity operation (e.g., proportional, custom)
     * @param bptAmountIn Amount of pool tokens to burn
     * @param amountsOutScaled18 Scaled amount of tokens to receive, sorted in token registration order
     * @param amountsOutRaw Actual amount of tokens to receive, sorted in token registration order
     * @param balancesScaled18 Current pool balances, sorted in token registration order
     * @param userData Additional (optional) data provided by the user
     * @return success True if the pool wishes to proceed with settlement
     * @return hookAdjustedAmountsOutRaw New amountsOutRaw, potentially modified by the hook
     */
    function onAfterRemoveLiquidity(
        address router,
        address pool,
        RemoveLiquidityKind kind,
        uint256 bptAmountIn,
        uint256[] memory amountsOutScaled18,
        uint256[] memory amountsOutRaw,
        uint256[] memory balancesScaled18,
        bytes memory userData
    ) external returns (bool success, uint256[] memory hookAdjustedAmountsOutRaw);

    /***************************************************************************
                                    Swap
    ***************************************************************************/

    /**
     * @notice Called before a swap to give the Pool an opportunity to perform actions.
     * @dev Called if the `shouldCallBeforeSwap` flag is set in the configuration. Hook contracts should use the
     * `onlyVault` modifier to guarantee this is only called by the Vault.
     *
     * @param params Swap parameters (see PoolSwapParams for struct definition)
     * @param pool Pool address, used to get pool information from the Vault (poolData, token config, etc.)
     * @return success True if the pool wishes to proceed with settlement
     */
    function onBeforeSwap(PoolSwapParams calldata params, address pool) external returns (bool success);

    /**
     * @notice Called after a swap to perform further actions once the balances have been updated by the swap.
     * @dev Called if the `shouldCallAfterSwap` flag is set in the configuration. The Vault will ignore
     * `hookAdjustedAmountCalculatedRaw` unless `enableHookAdjustedAmounts` is true. Hook contracts should
     * use the `onlyVault` modifier to guarantee this is only called by the Vault.
     *
     * @param params Swap parameters (see above for struct definition)
     * @return success True if the pool wishes to proceed with settlement
     * @return hookAdjustedAmountCalculatedRaw New amount calculated, potentially modified by the hook
     */
    function onAfterSwap(
        AfterSwapParams calldata params
    ) external returns (bool success, uint256 hookAdjustedAmountCalculatedRaw);

    /**
     * @notice Called after `onBeforeSwap` and before the main swap operation, if the pool has dynamic fees.
     * @dev Called if the `shouldCallComputeDynamicSwapFee` flag is set in the configuration. Hook contracts should use
     * the `onlyVault` modifier to guarantee this is only called by the Vault.
     *
     * @param params Swap parameters (see PoolSwapParams for struct definition)
     * @param pool Pool address, used to get pool information from the Vault (poolData, token config, etc.)
     * @param staticSwapFeePercentage 18-decimal FP value of the static swap fee percentage, for reference
     * @return success True if the pool wishes to proceed with settlement
     * @return dynamicSwapFeePercentage Value of the swap fee percentage, as an 18-decimal FP value
     */
    function onComputeDynamicSwapFeePercentage(
        PoolSwapParams calldata params,
        address pool,
        uint256 staticSwapFeePercentage
    ) external view returns (bool success, uint256 dynamicSwapFeePercentage);
}


// File: @balancer-labs/v3-interfaces/contracts/vault/IPoolLiquidity.sol

// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.24;

/// @notice Interface for custom liquidity operations.
interface IPoolLiquidity {
    /**
     * @notice Add liquidity to the pool with a custom hook.
     * @param router The address (usually a router contract) that initiated a swap operation on the Vault
     * @param maxAmountsInScaled18 Maximum input amounts, sorted in token registration order
     * @param minBptAmountOut Minimum amount of output pool tokens
     * @param balancesScaled18 Current pool balances, sorted in token registration order
     * @param userData Arbitrary data sent with the encoded request
     * @return amountsInScaled18 Input token amounts, sorted in token registration order
     * @return bptAmountOut Calculated pool token amount to receive
     * @return swapFeeAmountsScaled18 The amount of swap fees charged for each token
     * @return returnData Arbitrary data with an encoded response from the pool
     */
    function onAddLiquidityCustom(
        address router,
        uint256[] memory maxAmountsInScaled18,
        uint256 minBptAmountOut,
        uint256[] memory balancesScaled18,
        bytes memory userData
    )
        external
        returns (
            uint256[] memory amountsInScaled18,
            uint256 bptAmountOut,
            uint256[] memory swapFeeAmountsScaled18,
            bytes memory returnData
        );

    /**
     * @notice Remove liquidity from the pool with a custom hook.
     * @param router The address (usually a router contract) that initiated a swap operation on the Vault
     * @param maxBptAmountIn Maximum amount of input pool tokens
     * @param minAmountsOutScaled18 Minimum output amounts, sorted in token registration order
     * @param balancesScaled18 Current pool balances, sorted in token registration order
     * @param userData Arbitrary data sent with the encoded request
     * @return bptAmountIn Calculated pool token amount to burn
     * @return amountsOutScaled18 Amount of tokens to receive, sorted in token registration order
     * @return swapFeeAmountsScaled18 The amount of swap fees charged for each token
     * @return returnData Arbitrary data with an encoded response from the pool
     */
    function onRemoveLiquidityCustom(
        address router,
        uint256 maxBptAmountIn,
        uint256[] memory minAmountsOutScaled18,
        uint256[] memory balancesScaled18,
        bytes memory userData
    )
        external
        returns (
            uint256 bptAmountIn,
            uint256[] memory amountsOutScaled18,
            uint256[] memory swapFeeAmountsScaled18,
            bytes memory returnData
        );
}


// File: @balancer-labs/v3-interfaces/contracts/vault/IProtocolFeeController.sol

// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.24;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { IVault } from "./IVault.sol";

/// @notice Contract that handles protocol and pool creator fees for the Vault.
interface IProtocolFeeController {
    /**
     * @notice Emitted when the protocol swap fee percentage is updated.
     * @param swapFeePercentage The updated protocol swap fee percentage
     */
    event GlobalProtocolSwapFeePercentageChanged(uint256 swapFeePercentage);

    /**
     * @notice Emitted when the protocol yield fee percentage is updated.
     * @param yieldFeePercentage The updated protocol yield fee percentage
     */
    event GlobalProtocolYieldFeePercentageChanged(uint256 yieldFeePercentage);

    /**
     * @notice Emitted when the protocol swap fee percentage is updated for a specific pool.
     * @param pool The pool whose protocol swap fee will be changed
     * @param swapFeePercentage The updated protocol swap fee percentage
     */
    event ProtocolSwapFeePercentageChanged(address indexed pool, uint256 swapFeePercentage);

    /**
     * @notice Emitted when the protocol yield fee percentage is updated for a specific pool.
     * @param pool The pool whose protocol yield fee will be changed
     * @param yieldFeePercentage The updated protocol yield fee percentage
     */
    event ProtocolYieldFeePercentageChanged(address indexed pool, uint256 yieldFeePercentage);

    /**
     * @notice Emitted when the pool creator swap fee percentage of a pool is updated.
     * @param pool The pool whose pool creator swap fee will be changed
     * @param poolCreatorSwapFeePercentage The new pool creator swap fee percentage for the pool
     */
    event PoolCreatorSwapFeePercentageChanged(address indexed pool, uint256 poolCreatorSwapFeePercentage);

    /**
     * @notice Emitted when the pool creator yield fee percentage of a pool is updated.
     * @param pool The pool whose pool creator yield fee will be changed
     * @param poolCreatorYieldFeePercentage The new pool creator yield fee percentage for the pool
     */
    event PoolCreatorYieldFeePercentageChanged(address indexed pool, uint256 poolCreatorYieldFeePercentage);

    /**
     * @notice Logs the collection of protocol swap fees in a specific token and amount.
     * @dev Note that since charging protocol fees (i.e., distributing tokens between pool and fee balances) occurs
     * in the Vault, but fee collection happens in the ProtocolFeeController, the swap fees reported here may encompass
     * multiple operations.
     *
     * @param pool The pool on which the swap fee was charged
     * @param token The token in which the swap fee was charged
     * @param amount The amount of the token collected in fees
     */
    event ProtocolSwapFeeCollected(address indexed pool, IERC20 indexed token, uint256 amount);

    /**
     * @notice Logs the collection of protocol yield fees in a specific token and amount.
     * @dev Note that since charging protocol fees (i.e., distributing tokens between pool and fee balances) occurs
     * in the Vault, but fee collection happens in the ProtocolFeeController, the yield fees reported here may encompass
     * multiple operations.
     *
     * @param pool The pool on which the yield fee was charged
     * @param token The token in which the yield fee was charged
     * @param amount The amount of the token collected in fees
     */
    event ProtocolYieldFeeCollected(address indexed pool, IERC20 indexed token, uint256 amount);

    /**
     * @notice Logs the withdrawal of protocol fees in a specific token and amount.
     * @param pool The pool from which protocol fees are being withdrawn
     * @param token The token being withdrawn
     * @param recipient The recipient of the funds
     * @param amount The amount of the fee token that was withdrawn
     */
    event ProtocolFeesWithdrawn(address indexed pool, IERC20 indexed token, address indexed recipient, uint256 amount);

    /**
     * @notice Logs the withdrawal of pool creator fees in a specific token and amount.
     * @param pool The pool from which pool creator fees are being withdrawn
     * @param token The token being withdrawn
     * @param recipient The recipient of the funds (the pool creator if permissionless, or another account)
     * @param amount The amount of the fee token that was withdrawn
     */
    event PoolCreatorFeesWithdrawn(
        address indexed pool,
        IERC20 indexed token,
        address indexed recipient,
        uint256 amount
    );

    /**
     * @notice Error raised when the protocol swap fee percentage exceeds the maximum allowed value.
     * @dev Note that this is checked for both the global and pool-specific protocol swap fee percentages.
     */
    error ProtocolSwapFeePercentageTooHigh();

    /**
     * @notice Error raised when the protocol yield fee percentage exceeds the maximum allowed value.
     * @dev Note that this is checked for both the global and pool-specific protocol yield fee percentages.
     */
    error ProtocolYieldFeePercentageTooHigh();

    /**
     * @notice Error raised if there is no pool creator on a withdrawal attempt from the given pool.
     * @param pool The pool with no creator
     */
    error PoolCreatorNotRegistered(address pool);

    /**
     * @notice Error raised if the wrong account attempts to withdraw pool creator fees.
     * @param caller The account attempting to withdraw pool creator fees
     * @param pool The pool the caller tried to withdraw from
     */
    error CallerIsNotPoolCreator(address caller, address pool);

    /// @notice Error raised when the pool creator swap or yield fee percentage exceeds the maximum allowed value.
    error PoolCreatorFeePercentageTooHigh();

    /**
     * @notice Get the address of the main Vault contract.
     * @return vault The Vault address
     */
    function vault() external view returns (IVault);

    /**
     * @notice Collects aggregate fees from the Vault for a given pool.
     * @param pool The pool with aggregate fees
     */
    function collectAggregateFees(address pool) external;

    /**
     * @notice Getter for the current global protocol swap fee.
     * @return protocolSwapFeePercentage The global protocol swap fee percentage
     */
    function getGlobalProtocolSwapFeePercentage() external view returns (uint256 protocolSwapFeePercentage);

    /**
     * @notice Getter for the current global protocol yield fee.
     * @return protocolYieldFeePercentage The global protocol yield fee percentage
     */
    function getGlobalProtocolYieldFeePercentage() external view returns (uint256 protocolYieldFeePercentage);

    /**
     * @notice Getter for the current protocol swap fee for a given pool.
     * @param pool The address of the pool
     * @return protocolSwapFeePercentage The global protocol swap fee percentage
     * @return isOverride True if the protocol fee has been overridden
     */
    function getPoolProtocolSwapFeeInfo(
        address pool
    ) external view returns (uint256 protocolSwapFeePercentage, bool isOverride);

    /**
     * @notice Getter for the current protocol yield fee for a given pool.
     * @param pool The address of the pool
     * @return protocolYieldFeePercentage The global protocol yield fee percentage
     * @return isOverride True if the protocol fee has been overridden
     */
    function getPoolProtocolYieldFeeInfo(
        address pool
    ) external view returns (uint256 protocolYieldFeePercentage, bool isOverride);

    /**
     * @notice Returns the amount of each pool token allocated to the protocol for withdrawal.
     * @dev Includes both swap and yield fees.
     * @param pool The address of the pool on which fees were collected
     * @return feeAmounts The total amounts of each token available for withdrawal, sorted in token registration order
     */
    function getProtocolFeeAmounts(address pool) external view returns (uint256[] memory feeAmounts);

    /**
     * @notice Returns the amount of each pool token allocated to the pool creator for withdrawal.
     * @dev Includes both swap and yield fees.
     * @param pool The address of the pool on which fees were collected
     * @return feeAmounts The total amounts of each token available for withdrawal, sorted in token registration order
     */
    function getPoolCreatorFeeAmounts(address pool) external view returns (uint256[] memory feeAmounts);

    /**
     * @notice Returns a calculated aggregate percentage from protocol and pool creator fee percentages.
     * @dev Not tied to any particular pool; this just performs the low-level "additive fee" calculation. Note that
     * pool creator fees are calculated based on creatorAndLpFees, and not in totalFees. Since aggregate fees are
     * stored in the Vault with 24-bit precision, this will truncate any values that require greater precision.
     * It is expected that pool creators will negotiate with the DAO and agree on reasonable values for these fee
     * components, but the truncation ensures it will not revert for any valid set of fee percentages.
     *
     * See example below:
     *
     * tokenOutAmount = 10000; poolSwapFeePct = 10%; protocolFeePct = 40%; creatorFeePct = 60%
     * totalFees = tokenOutAmount * poolSwapFeePct = 10000 * 10% = 1000
     * protocolFees = totalFees * protocolFeePct = 1000 * 40% = 400
     * creatorAndLpFees = totalFees - protocolFees = 1000 - 400 = 600
     * creatorFees = creatorAndLpFees * creatorFeePct = 600 * 60% = 360
     * lpFees (will stay in the pool) = creatorAndLpFees - creatorFees = 600 - 360 = 240
     *
     * @param protocolFeePercentage The protocol portion of the aggregate fee percentage
     * @param poolCreatorFeePercentage The pool creator portion of the aggregate fee percentage
     * @return aggregateFeePercentage The computed aggregate percentage
     */
    function computeAggregateFeePercentage(
        uint256 protocolFeePercentage,
        uint256 poolCreatorFeePercentage
    ) external pure returns (uint256 aggregateFeePercentage);

    /**
     * @notice Override the protocol swap fee percentage for a specific pool.
     * @dev This is a permissionless call, and will set the pool's fee to the current global fee, if it is different
     * from the current value, and the fee is not controlled by governance (i.e., has never been overridden).
     *
     * @param pool The pool for which we are setting the protocol swap fee
     */
    function updateProtocolSwapFeePercentage(address pool) external;

    /**
     * @notice Override the protocol yield fee percentage for a specific pool.
     * @dev This is a permissionless call, and will set the pool's fee to the current global fee, if it is different
     * from the current value, and the fee is not controlled by governance (i.e., has never been overridden).
     *
     * @param pool The pool for which we are setting the protocol yield fee
     */
    function updateProtocolYieldFeePercentage(address pool) external;

    /***************************************************************************
                                Permissioned Functions
    ***************************************************************************/

    /**
     * @notice Add pool-specific entries to the protocol swap and yield percentages.
     * @dev This must be called from the Vault during pool registration. It will initialize the pool to the global
     * protocol fee percentage values (or 0, if the `protocolFeeExempt` flags is set), and return the initial aggregate
     * fee percentages, based on an initial pool creator fee of 0.
     *
     * @param pool The address of the pool being registered
     * @param poolCreator The address of the pool creator (or 0 if there won't be a pool creator fee)
     * @param protocolFeeExempt If true, the pool is initially exempt from protocol fees
     * @return aggregateSwapFeePercentage The initial aggregate swap fee percentage
     * @return aggregateYieldFeePercentage The initial aggregate yield fee percentage
     */
    function registerPool(
        address pool,
        address poolCreator,
        bool protocolFeeExempt
    ) external returns (uint256 aggregateSwapFeePercentage, uint256 aggregateYieldFeePercentage);

    /**
     * @notice Set the global protocol swap fee percentage, used by standard pools.
     * @param newProtocolSwapFeePercentage The new protocol swap fee percentage
     */
    function setGlobalProtocolSwapFeePercentage(uint256 newProtocolSwapFeePercentage) external;

    /**
     * @notice Set the global protocol yield fee percentage, used by standard pools.
     * @param newProtocolYieldFeePercentage The new protocol yield fee percentage
     */
    function setGlobalProtocolYieldFeePercentage(uint256 newProtocolYieldFeePercentage) external;

    /**
     * @notice Override the protocol swap fee percentage for a specific pool.
     * @param pool The address of the pool for which we are setting the protocol swap fee
     * @param newProtocolSwapFeePercentage The new protocol swap fee percentage for the pool
     */
    function setProtocolSwapFeePercentage(address pool, uint256 newProtocolSwapFeePercentage) external;

    /**
     * @notice Override the protocol yield fee percentage for a specific pool.
     * @param pool The address of the pool for which we are setting the protocol yield fee
     * @param newProtocolYieldFeePercentage The new protocol yield fee percentage for the pool
     */
    function setProtocolYieldFeePercentage(address pool, uint256 newProtocolYieldFeePercentage) external;

    /**
     * @notice Assigns a new pool creator swap fee percentage to the specified pool.
     * @dev Fees are divided between the protocol, pool creator, and LPs. The pool creator percentage is applied to
     * the "net" amount after protocol fees, and divides the remainder between the pool creator and LPs. If the
     * pool creator fee is near 100%, almost none of the fee amount remains in the pool for LPs.
     *
     * @param pool The address of the pool for which the pool creator fee will be changed
     * @param poolCreatorSwapFeePercentage The new pool creator swap fee percentage to apply to the pool
     */
    function setPoolCreatorSwapFeePercentage(address pool, uint256 poolCreatorSwapFeePercentage) external;

    /**
     * @notice Assigns a new pool creator yield fee percentage to the specified pool.
     * @dev Fees are divided between the protocol, pool creator, and LPs. The pool creator percentage is applied to
     * the "net" amount after protocol fees, and divides the remainder between the pool creator and LPs. If the
     * pool creator fee is near 100%, almost none of the fee amount remains in the pool for LPs.
     *
     * @param pool The address of the pool for which the pool creator fee will be changed
     * @param poolCreatorYieldFeePercentage The new pool creator yield fee percentage to apply to the pool
     */
    function setPoolCreatorYieldFeePercentage(address pool, uint256 poolCreatorYieldFeePercentage) external;

    /**
     * @notice Withdraw collected protocol fees for a given pool (all tokens). This is a permissioned function.
     * @dev Sends swap and yield protocol fees to the recipient.
     * @param pool The pool on which fees were collected
     * @param recipient Address to send the tokens
     */
    function withdrawProtocolFees(address pool, address recipient) external;

    /**
     * @notice Withdraw collected protocol fees for a given pool and a given token. This is a permissioned function.
     * @dev Sends swap and yield protocol fees to the recipient.
     * @param pool The pool on which fees were collected
     * @param recipient Address to send the tokens
     * @param token Token to withdraw
     */
    function withdrawProtocolFeesForToken(address pool, address recipient, IERC20 token) external;

    /**
     * @notice Withdraw collected pool creator fees for a given pool. This is a permissioned function.
     * @dev Sends swap and yield pool creator fees to the recipient.
     * @param pool The pool on which fees were collected
     * @param recipient Address to send the tokens
     */
    function withdrawPoolCreatorFees(address pool, address recipient) external;

    /**
     * @notice Withdraw collected pool creator fees for a given pool.
     * @dev Sends swap and yield pool creator fees to the registered poolCreator. Since this is a known and immutable
     * value, this function is permissionless.
     *
     * @param pool The pool on which fees were collected
     */
    function withdrawPoolCreatorFees(address pool) external;
}


// File: @balancer-labs/v3-interfaces/contracts/vault/ISwapFeePercentageBounds.sol

// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.24;

/**
 * @notice Return the minimum/maximum swap fee percentages for a pool.
 * @dev The Vault does not enforce bounds on swap fee percentages; `IBasePool` implements this interface to ensure
 * that new pool developers think about and set these bounds according to their specific pool type.
 *
 * A minimum swap fee might be necessary to ensure mathematical soundness (e.g., Weighted Pools, which use the power
 * function in the invariant). A maximum swap fee is general protection for users. With no limits at the Vault level,
 * a pool could specify a near 100% swap fee, effectively disabling trading. Though there are some use cases, such as
 * LVR/MEV strategies, where a very high fee makes sense.
 *
 * Note that the Vault does ensure that dynamic and aggregate fees are less than 100% to prevent attempting to allocate
 * more fees than were collected by the operation. The true `MAX_FEE_PERCENTAGE` is defined in VaultTypes.sol, and is
 * the highest value below 100% that satisfies the precision requirements.
 */
interface ISwapFeePercentageBounds {
    /// @return minimumSwapFeePercentage The minimum swap fee percentage for a pool
    function getMinimumSwapFeePercentage() external view returns (uint256 minimumSwapFeePercentage);

    /// @return maximumSwapFeePercentage The maximum swap fee percentage for a pool
    function getMaximumSwapFeePercentage() external view returns (uint256 maximumSwapFeePercentage);
}


// File: @balancer-labs/v3-interfaces/contracts/vault/IUnbalancedLiquidityInvariantRatioBounds.sol

// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.24;

/**
 * @notice Return the minimum/maximum invariant ratios allowed during an unbalanced liquidity operation.
 * @dev The Vault does not enforce any "baseline" bounds on invariant ratios, since such bounds are highly specific
 * and dependent on the math of each pool type. Instead, the Vault reads invariant ratio bounds from the pools.
 * `IBasePool` implements this interface to ensure that new pool developers think about and set these bounds according
 * to their pool type's math.
 *
 * For instance, Balancer Weighted Pool math involves exponentiation (the `pow` function), which uses natural
 * logarithms and a discrete Taylor series expansion to compute x^y values for the 18-decimal floating point numbers
 * used in all Vault computations. See `LogExpMath` and `WeightedMath` for a derivation of the bounds for these pools.
 */
interface IUnbalancedLiquidityInvariantRatioBounds {
    /// @return minimumInvariantRatio The minimum invariant ratio for a pool during unbalanced remove liquidity
    function getMinimumInvariantRatio() external view returns (uint256 minimumInvariantRatio);

    /// @return maximumInvariantRatio The maximum invariant ratio for a pool during unbalanced add liquidity
    function getMaximumInvariantRatio() external view returns (uint256 maximumInvariantRatio);
}


// File: @balancer-labs/v3-interfaces/contracts/vault/IVault.sol

// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.24;

import { IAuthentication } from "../solidity-utils/helpers/IAuthentication.sol";
import { IVaultExtension } from "./IVaultExtension.sol";
import { IVaultErrors } from "./IVaultErrors.sol";
import { IVaultEvents } from "./IVaultEvents.sol";
import { IVaultAdmin } from "./IVaultAdmin.sol";
import { IVaultMain } from "./IVaultMain.sol";

/// @notice Composite interface for all Vault operations: swap, add/remove liquidity, and associated queries.
interface IVault is IVaultMain, IVaultExtension, IVaultAdmin, IVaultErrors, IVaultEvents, IAuthentication {
    /// @return vault The main Vault address.
    function vault() external view override(IVaultAdmin, IVaultExtension) returns (IVault);
}


// File: @balancer-labs/v3-interfaces/contracts/vault/IVaultAdmin.sol

// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.24;

import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";

import { IProtocolFeeController } from "./IProtocolFeeController.sol";
import { IAuthorizer } from "./IAuthorizer.sol";
import { IVault } from "./IVault.sol";

/**
 * @notice Interface for functions defined on the `VaultAdmin` contract.
 * @dev `VaultAdmin` is the Proxy extension of `VaultExtension`, and handles the least critical operations,
 * as two delegate calls add gas to each call. Most of the permissioned calls are here.
 */
interface IVaultAdmin {
    /*******************************************************************************
                               Constants and immutables
    *******************************************************************************/

    /**
     * @notice Returns the main Vault address.
     * @dev The main Vault contains the entrypoint and main liquidity operation implementations.
     * @return vault The address of the main Vault
     */
    function vault() external view returns (IVault);

    /**
     * @notice Returns the Vault's pause window end time.
     * @dev This value is immutable, and represents the timestamp after which the Vault can no longer be paused
     * by governance. Balancer timestamps are 32 bits.
     *
     * @return pauseWindowEndTime The timestamp when the Vault's pause window ends
     */
    function getPauseWindowEndTime() external view returns (uint32 pauseWindowEndTime);

    /**
     * @notice Returns the Vault's buffer period duration.
     * @dev This value is immutable. It represents the period during which, if paused, the Vault will remain paused.
     * This ensures there is time available to address whatever issue caused the Vault to be paused. Balancer
     * timestamps are 32 bits.
     *
     * @return bufferPeriodDuration The length of the buffer period in seconds
     */
    function getBufferPeriodDuration() external view returns (uint32 bufferPeriodDuration);

    /**
     * @notice Returns the Vault's buffer period end time.
     * @dev This value is immutable. If already paused, the Vault can be unpaused until this timestamp. Balancer
     * timestamps are 32 bits.
     *
     * @return bufferPeriodEndTime The timestamp after which the Vault remains permanently unpaused
     */
    function getBufferPeriodEndTime() external view returns (uint32 bufferPeriodEndTime);

    /**
     * @notice Get the minimum number of tokens in a pool.
     * @dev We expect the vast majority of pools to be 2-token.
     * @return minTokens The minimum token count of a pool
     */
    function getMinimumPoolTokens() external pure returns (uint256 minTokens);

    /**
     * @notice Get the maximum number of tokens in a pool.
     * @return maxTokens The maximum token count of a pool
     */
    function getMaximumPoolTokens() external pure returns (uint256 maxTokens);

    /**
     * @notice Get the minimum total supply of pool tokens (BPT) for an initialized pool.
     * @dev This prevents pools from being completely drained. When the pool is initialized, this minimum amount of BPT
     * is minted to the zero address. This is an 18-decimal floating point number; BPT are always 18 decimals.
     *
     * @return poolMinimumTotalSupply The minimum total supply a pool can have after initialization
     */
    function getPoolMinimumTotalSupply() external pure returns (uint256 poolMinimumTotalSupply);

    /**
     * @notice Get the minimum total supply of an ERC4626 wrapped token buffer in the Vault.
     * @dev This prevents buffers from being completely drained. When the buffer is initialized, this minimum number
     * of shares is added to the shares resulting from the initial deposit. Buffer total supply accounting is internal
     * to the Vault, as buffers are not tokenized.
     *
     * @return bufferMinimumTotalSupply The minimum total supply a buffer can have after initialization
     */
    function getBufferMinimumTotalSupply() external pure returns (uint256 bufferMinimumTotalSupply);

    /**
     * @notice Get the minimum trade amount in a pool operation.
     * @dev This limit is applied to the 18-decimal "upscaled" amount in any operation (swap, add/remove liquidity).
     * @return minimumTradeAmount The minimum trade amount as an 18-decimal floating point number
     */
    function getMinimumTradeAmount() external view returns (uint256 minimumTradeAmount);

    /**
     * @notice Get the minimum wrap amount in a buffer operation.
     * @dev This limit is applied to the wrap operation amount, in native underlying token decimals.
     * @return minimumWrapAmount The minimum wrap amount in native underlying token decimals
     */
    function getMinimumWrapAmount() external view returns (uint256 minimumWrapAmount);

    /*******************************************************************************
                                    Vault Pausing
    *******************************************************************************/

    /**
     * @notice Indicates whether the Vault is paused.
     * @dev If the Vault is paused, all non-Recovery Mode state-changing operations on pools will revert. Note that
     * ERC4626 buffers and the Vault have separate and independent pausing mechanisms. Pausing the Vault does not
     * also pause buffers (though we anticipate they would likely be paused and unpaused together). Call
     * `areBuffersPaused` to check the pause state of the buffers.
     *
     * @return vaultPaused True if the Vault is paused
     */
    function isVaultPaused() external view returns (bool vaultPaused);

    /**
     * @notice Returns the paused status, and end times of the Vault's pause window and buffer period.
     * @dev Balancer timestamps are 32 bits.
     * @return vaultPaused True if the Vault is paused
     * @return vaultPauseWindowEndTime The timestamp of the end of the Vault's pause window
     * @return vaultBufferPeriodEndTime The timestamp of the end of the Vault's buffer period
     */
    function getVaultPausedState()
        external
        view
        returns (bool vaultPaused, uint32 vaultPauseWindowEndTime, uint32 vaultBufferPeriodEndTime);

    /**
     * @notice Pause the Vault: an emergency action which disables all operational state-changing functions on pools.
     * @dev This is a permissioned function that will only work during the Pause Window set during deployment.
     * Note that ERC4626 buffer operations have an independent pause mechanism, which is not affected by pausing
     * the Vault. Custom routers could still wrap/unwrap using buffers while the Vault is paused, unless buffers
     * are also paused (with `pauseVaultBuffers`).
     */
    function pauseVault() external;

    /**
     * @notice Reverse a `pause` operation, and restore Vault pool operations to normal functionality.
     * @dev This is a permissioned function that will only work on a paused Vault within the Buffer Period set during
     * deployment. Note that the Vault will automatically unpause after the Buffer Period expires. As noted above,
     * ERC4626 buffers and Vault operations on pools are independent. Unpausing the Vault does not reverse
     * `pauseVaultBuffers`. If buffers were also paused, they will remain in that state until explicitly unpaused.
     */
    function unpauseVault() external;

    /*******************************************************************************
                                    Pool Pausing
    *******************************************************************************/

    /**
     * @notice Pause the Pool: an emergency action which disables all pool functions.
     * @dev This is a permissioned function that will only work during the Pause Window set during pool factory
     * deployment.
     *
     * @param pool The pool being paused
     */
    function pausePool(address pool) external;

    /**
     * @notice Reverse a `pause` operation, and restore the Pool to normal functionality.
     * @dev This is a permissioned function that will only work on a paused Pool within the Buffer Period set during
     * deployment. Note that the Pool will automatically unpause after the Buffer Period expires.
     *
     * @param pool The pool being unpaused
     */
    function unpausePool(address pool) external;

    /*******************************************************************************
                                         Fees
    *******************************************************************************/

    /**
     * @notice Assigns a new static swap fee percentage to the specified pool.
     * @dev This is a permissioned function, disabled if the pool is paused. The swap fee percentage must be within
     * the bounds specified by the pool's implementation of `ISwapFeePercentageBounds`.
     * Emits the SwapFeePercentageChanged event.
     *
     * @param pool The address of the pool for which the static swap fee will be changed
     * @param swapFeePercentage The new swap fee percentage to apply to the pool
     */
    function setStaticSwapFeePercentage(address pool, uint256 swapFeePercentage) external;

    /**
     * @notice Collects accumulated aggregate swap and yield fees for the specified pool.
     * @dev Fees are sent to the ProtocolFeeController address.
     * @param pool The pool on which all aggregate fees should be collected
     * @return swapFeeAmounts An array with the total swap fees collected, sorted in token registration order
     * @return yieldFeeAmounts An array with the total yield fees collected, sorted in token registration order
     */
    function collectAggregateFees(
        address pool
    ) external returns (uint256[] memory swapFeeAmounts, uint256[] memory yieldFeeAmounts);

    /**
     * @notice Update an aggregate swap fee percentage.
     * @dev Can only be called by the current protocol fee controller. Called when governance overrides a protocol fee
     * for a specific pool, or to permissionlessly update a pool to a changed global protocol fee value (if the pool's
     * fee has not previously been set by governance). Ensures the aggregate percentage <= FixedPoint.ONE, and also
     * that the final value does not lose precision when stored in 24 bits (see `FEE_BITLENGTH` in VaultTypes.sol).
     * Emits an `AggregateSwapFeePercentageChanged` event.
     *
     * @param pool The pool whose swap fee percentage will be updated
     * @param newAggregateSwapFeePercentage The new aggregate swap fee percentage
     */
    function updateAggregateSwapFeePercentage(address pool, uint256 newAggregateSwapFeePercentage) external;

    /**
     * @notice Update an aggregate yield fee percentage.
     * @dev Can only be called by the current protocol fee controller. Called when governance overrides a protocol fee
     * for a specific pool, or to permissionlessly update a pool to a changed global protocol fee value (if the pool's
     * fee has not previously been set by governance). Ensures the aggregate percentage <= FixedPoint.ONE, and also
     * that the final value does not lose precision when stored in 24 bits (see `FEE_BITLENGTH` in VaultTypes.sol).
     * Emits an `AggregateYieldFeePercentageChanged` event.
     *
     * @param pool The pool whose yield fee percentage will be updated
     * @param newAggregateYieldFeePercentage The new aggregate yield fee percentage
     */
    function updateAggregateYieldFeePercentage(address pool, uint256 newAggregateYieldFeePercentage) external;

    /**
     * @notice Sets a new Protocol Fee Controller for the Vault.
     * @dev This is a permissioned call. Emits a `ProtocolFeeControllerChanged` event.
     * @param newProtocolFeeController The address of the new Protocol Fee Controller
     */
    function setProtocolFeeController(IProtocolFeeController newProtocolFeeController) external;

    /*******************************************************************************
                                    Recovery Mode
    *******************************************************************************/

    /**
     * @notice Enable recovery mode for a pool.
     * @dev This is a permissioned function. It enables a safe proportional withdrawal, with no external calls.
     * Since there are no external calls, ensuring that entering Recovery Mode cannot fail, we cannot compute and so
     * must forfeit any yield fees between the last operation and enabling Recovery Mode. For the same reason, live
     * balances cannot be updated while in Recovery Mode, as doing so might cause withdrawals to fail.
     *
     * @param pool The address of the pool
     */
    function enableRecoveryMode(address pool) external;

    /**
     * @notice Disable recovery mode for a pool.
     * @dev This is a permissioned function. It re-syncs live balances (which could not be updated during
     * Recovery Mode), forfeiting any yield fees that accrued while enabled. It makes external calls, and could
     * potentially fail if there is an issue with any associated Rate Providers.
     *
     * @param pool The address of the pool
     */
    function disableRecoveryMode(address pool) external;

    /*******************************************************************************
                                  Query Functionality
    *******************************************************************************/

    /**
     * @notice Disables query functionality on the Vault. Can only be called by governance.
     * @dev The query functions rely on a specific EVM feature to detect static calls. Query operations are exempt from
     * settlement constraints, so it's critical that no state changes can occur. We retain the ability to disable
     * queries in the unlikely event that EVM changes violate its assumptions (perhaps on an L2).
     * This function can be acted upon as an emergency measure in ambiguous contexts where it's not 100% clear whether
     * disabling queries is completely necessary; queries can still be re-enabled after this call.
     */
    function disableQuery() external;

    /**
     * @notice Disables query functionality permanently on the Vault. Can only be called by governance.
     * @dev Shall only be used when there is no doubt that queries pose a fundamental threat to the system.
     */
    function disableQueryPermanently() external;

    /**
     * @notice Enables query functionality on the Vault. Can only be called by governance.
     * @dev Only works if queries are not permanently disabled.
     */
    function enableQuery() external;

    /*******************************************************************************
                                  ERC4626 Buffers
    *******************************************************************************/

    /**
     * @notice Indicates whether the Vault buffers are paused.
     * @dev When buffers are paused, all buffer operations (i.e., calls on the Router with `isBuffer` true)
     * will revert. Pausing buffers is reversible. Note that ERC4626 buffers and the Vault have separate and
     * independent pausing mechanisms. Pausing the Vault does not also pause buffers (though we anticipate they
     * would likely be paused and unpaused together). Call `isVaultPaused` to check the pause state of the Vault.
     *
     * @return buffersPaused True if the Vault buffers are paused
     */
    function areBuffersPaused() external view returns (bool buffersPaused);

    /**
     * @notice Pauses native vault buffers globally.
     * @dev When buffers are paused, it's not possible to add liquidity or wrap/unwrap tokens using the Vault's
     * `erc4626BufferWrapOrUnwrap` primitive. However, it's still possible to remove liquidity. Currently it's not
     * possible to pause vault buffers individually.
     *
     * This is a permissioned call, and is reversible (see `unpauseVaultBuffers`). Note that the Vault has a separate
     * and independent pausing mechanism. It is possible to pause the Vault (i.e. pool operations), without affecting
     * buffers, and vice versa.
     */
    function pauseVaultBuffers() external;

    /**
     * @notice Unpauses native vault buffers globally.
     * @dev When buffers are paused, it's not possible to add liquidity or wrap/unwrap tokens using the Vault's
     * `erc4626BufferWrapOrUnwrap` primitive. However, it's still possible to remove liquidity. As noted above,
     * ERC4626 buffers and Vault operations on pools are independent. Unpausing buffers does not reverse `pauseVault`.
     * If the Vault was also paused, it will remain in that state until explicitly unpaused.
     *
     * This is a permissioned call.
     */
    function unpauseVaultBuffers() external;

    /**
     * @notice Initializes buffer for the given wrapped token.
     * @param wrappedToken Address of the wrapped token that implements IERC4626
     * @param amountUnderlyingRaw Amount of underlying tokens that will be deposited into the buffer
     * @param amountWrappedRaw Amount of wrapped tokens that will be deposited into the buffer
     * @param minIssuedShares Minimum amount of shares to receive from the buffer, expressed in underlying token
     * native decimals
     * @param sharesOwner Address that will own the deposited liquidity. Only this address will be able to remove
     * liquidity from the buffer
     * @return issuedShares the amount of tokens sharesOwner has in the buffer, expressed in underlying token amounts.
     * (it is the BPT of an internal ERC4626 buffer). It is expressed in underlying token native decimals.
     */
    function initializeBuffer(
        IERC4626 wrappedToken,
        uint256 amountUnderlyingRaw,
        uint256 amountWrappedRaw,
        uint256 minIssuedShares,
        address sharesOwner
    ) external returns (uint256 issuedShares);

    /**
     * @notice Adds liquidity to an internal ERC4626 buffer in the Vault, proportionally.
     * @dev The buffer needs to be initialized beforehand.
     * @param wrappedToken Address of the wrapped token that implements IERC4626
     * @param maxAmountUnderlyingInRaw Maximum amount of underlying tokens to add to the buffer. It is expressed in
     * underlying token native decimals
     * @param maxAmountWrappedInRaw Maximum amount of wrapped tokens to add to the buffer. It is expressed in wrapped
     * token native decimals
     * @param exactSharesToIssue The value in underlying tokens that `sharesOwner` wants to add to the buffer,
     * in underlying token decimals
     * @param sharesOwner Address that will own the deposited liquidity. Only this address will be able to remove
     * liquidity from the buffer
     * @return amountUnderlyingRaw Amount of underlying tokens deposited into the buffer
     * @return amountWrappedRaw Amount of wrapped tokens deposited into the buffer
     */
    function addLiquidityToBuffer(
        IERC4626 wrappedToken,
        uint256 maxAmountUnderlyingInRaw,
        uint256 maxAmountWrappedInRaw,
        uint256 exactSharesToIssue,
        address sharesOwner
    ) external returns (uint256 amountUnderlyingRaw, uint256 amountWrappedRaw);

    /**
     * @notice Removes liquidity from an internal ERC4626 buffer in the Vault.
     * @dev Only proportional exits are supported, and the sender has to be the owner of the shares.
     * This function unlocks the Vault just for this operation; it does not work with a Router as an entrypoint.
     *
     * Pre-conditions:
     * - The buffer needs to be initialized.
     * - sharesOwner is the original msg.sender, it needs to be checked in the Router. That's why
     *   this call is authenticated; only routers approved by the DAO can remove the liquidity of a buffer.
     * - The buffer needs to have some liquidity and have its asset registered in `_bufferAssets` storage.
     *
     * @param wrappedToken Address of the wrapped token that implements IERC4626
     * @param sharesToRemove Amount of shares to remove from the buffer. Cannot be greater than sharesOwner's
     * total shares. It is expressed in underlying token native decimals
     * @param minAmountUnderlyingOutRaw Minimum amount of underlying tokens to receive from the buffer. It is expressed
     * in underlying token native decimals
     * @param minAmountWrappedOutRaw Minimum amount of wrapped tokens to receive from the buffer. It is expressed in
     * wrapped token native decimals
     * @return removedUnderlyingBalanceRaw Amount of underlying tokens returned to the user
     * @return removedWrappedBalanceRaw Amount of wrapped tokens returned to the user
     */
    function removeLiquidityFromBuffer(
        IERC4626 wrappedToken,
        uint256 sharesToRemove,
        uint256 minAmountUnderlyingOutRaw,
        uint256 minAmountWrappedOutRaw
    ) external returns (uint256 removedUnderlyingBalanceRaw, uint256 removedWrappedBalanceRaw);

    /**
     * @notice Returns the asset registered for a given wrapped token.
     * @dev The asset can never change after buffer initialization.
     * @param wrappedToken Address of the wrapped token that implements IERC4626
     * @return underlyingToken Address of the underlying token registered for the wrapper; `address(0)` if the buffer
     * has not been initialized.
     */
    function getBufferAsset(IERC4626 wrappedToken) external view returns (address underlyingToken);

    /**
     * @notice Returns the shares (internal buffer BPT) of a liquidity owner: a user that deposited assets
     * in the buffer.
     *
     * @param wrappedToken Address of the wrapped token that implements IERC4626
     * @param liquidityOwner Address of the user that owns liquidity in the wrapped token's buffer
     * @return ownerShares Amount of shares allocated to the liquidity owner, in native underlying token decimals
     */
    function getBufferOwnerShares(
        IERC4626 wrappedToken,
        address liquidityOwner
    ) external view returns (uint256 ownerShares);

    /**
     * @notice Returns the supply shares (internal buffer BPT) of the ERC4626 buffer.
     * @param wrappedToken Address of the wrapped token that implements IERC4626
     * @return bufferShares Amount of supply shares of the buffer, in native underlying token decimals
     */
    function getBufferTotalShares(IERC4626 wrappedToken) external view returns (uint256 bufferShares);

    /**
     * @notice Returns the amount of underlying and wrapped tokens deposited in the internal buffer of the Vault.
     * @dev All values are in native token decimals of the wrapped or underlying tokens.
     * @param wrappedToken Address of the wrapped token that implements IERC4626
     * @return underlyingBalanceRaw Amount of underlying tokens deposited into the buffer, in native token decimals
     * @return wrappedBalanceRaw Amount of wrapped tokens deposited into the buffer, in native token decimals
     */
    function getBufferBalance(
        IERC4626 wrappedToken
    ) external view returns (uint256 underlyingBalanceRaw, uint256 wrappedBalanceRaw);

    /*******************************************************************************
                                Authentication
    *******************************************************************************/

    /**
     * @notice Sets a new Authorizer for the Vault.
     * @dev This is a permissioned call. Emits an `AuthorizerChanged` event.
     * @param newAuthorizer The address of the new authorizer
     */
    function setAuthorizer(IAuthorizer newAuthorizer) external;
}


// File: @balancer-labs/v3-interfaces/contracts/vault/IVaultErrors.sol

// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.24;

import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @notice Errors are declared inside an interface (namespace) to improve DX with Typechain.
interface IVaultErrors {
    /*******************************************************************************
                            Registration and Initialization
    *******************************************************************************/

    /**
     * @notice A pool has already been registered. `registerPool` may only be called once.
     * @param pool The already registered pool
     */
    error PoolAlreadyRegistered(address pool);

    /**
     * @notice A pool has already been initialized. `initialize` may only be called once.
     * @param pool The already initialized pool
     */
    error PoolAlreadyInitialized(address pool);

    /**
     * @notice A pool has not been registered.
     * @param pool The unregistered pool
     */
    error PoolNotRegistered(address pool);

    /**
     * @notice A referenced pool has not been initialized.
     * @param pool The uninitialized pool
     */
    error PoolNotInitialized(address pool);

    /**
     * @notice A hook contract rejected a pool on registration.
     * @param poolHooksContract Address of the hook contract that rejected the pool registration
     * @param pool Address of the rejected pool
     * @param poolFactory Address of the pool factory
     */
    error HookRegistrationFailed(address poolHooksContract, address pool, address poolFactory);

    /**
     * @notice A token was already registered (i.e., it is a duplicate in the pool).
     * @param token The duplicate token
     */
    error TokenAlreadyRegistered(IERC20 token);

    /// @notice The token count is below the minimum allowed.
    error MinTokens();

    /// @notice The token count is above the maximum allowed.
    error MaxTokens();

    /// @notice Invalid tokens (e.g., zero) cannot be registered.
    error InvalidToken();

    /// @notice The token type given in a TokenConfig during pool registration is invalid.
    error InvalidTokenType();

    /// @notice The data in a TokenConfig struct is inconsistent or unsupported.
    error InvalidTokenConfiguration();

    /// @notice Tokens with more than 18 decimals are not supported.
    error InvalidTokenDecimals();

    /**
     * @notice The token list passed into an operation does not match the pool tokens in the pool.
     * @param pool Address of the pool
     * @param expectedToken The correct token at a given index in the pool
     * @param actualToken The actual token found at that index
     */
    error TokensMismatch(address pool, address expectedToken, address actualToken);

    /*******************************************************************************
                                 Transient Accounting
    *******************************************************************************/

    /// @notice A transient accounting operation completed with outstanding token deltas.
    error BalanceNotSettled();

    /// @notice A user called a Vault function (swap, add/remove liquidity) outside the lock context.
    error VaultIsNotUnlocked();

    /// @notice The pool has returned false to the beforeSwap hook, indicating the transaction should revert.
    error DynamicSwapFeeHookFailed();

    /// @notice The pool has returned false to the beforeSwap hook, indicating the transaction should revert.
    error BeforeSwapHookFailed();

    /// @notice The pool has returned false to the afterSwap hook, indicating the transaction should revert.
    error AfterSwapHookFailed();

    /// @notice The pool has returned false to the beforeInitialize hook, indicating the transaction should revert.
    error BeforeInitializeHookFailed();

    /// @notice The pool has returned false to the afterInitialize hook, indicating the transaction should revert.
    error AfterInitializeHookFailed();

    /// @notice The pool has returned false to the beforeAddLiquidity hook, indicating the transaction should revert.
    error BeforeAddLiquidityHookFailed();

    /// @notice The pool has returned false to the afterAddLiquidity hook, indicating the transaction should revert.
    error AfterAddLiquidityHookFailed();

    /// @notice The pool has returned false to the beforeRemoveLiquidity hook, indicating the transaction should revert.
    error BeforeRemoveLiquidityHookFailed();

    /// @notice The pool has returned false to the afterRemoveLiquidity hook, indicating the transaction should revert.
    error AfterRemoveLiquidityHookFailed();

    /// @notice An unauthorized Router tried to call a permissioned function (i.e., using the Vault's token allowance).
    error RouterNotTrusted();

    /*******************************************************************************
                                        Swaps
    *******************************************************************************/

    /// @notice The user tried to swap zero tokens.
    error AmountGivenZero();

    /// @notice The user attempted to swap a token for itself.
    error CannotSwapSameToken();

    /**
     * @notice The user attempted to operate with a token that is not in the pool.
     * @param token The unregistered token
     */
    error TokenNotRegistered(IERC20 token);

    /**
     * @notice An amount in or out has exceeded the limit specified in the swap request.
     * @param amount The total amount in or out
     * @param limit The amount of the limit that has been exceeded
     */
    error SwapLimit(uint256 amount, uint256 limit);

    /**
     * @notice A hook adjusted amount in or out has exceeded the limit specified in the swap request.
     * @param amount The total amount in or out
     * @param limit The amount of the limit that has been exceeded
     */
    error HookAdjustedSwapLimit(uint256 amount, uint256 limit);

    /// @notice The amount given or calculated for an operation is below the minimum limit.
    error TradeAmountTooSmall();

    /*******************************************************************************
                                    Add Liquidity
    *******************************************************************************/

    /// @notice Add liquidity kind not supported.
    error InvalidAddLiquidityKind();

    /**
     * @notice A required amountIn exceeds the maximum limit specified for the operation.
     * @param tokenIn The incoming token
     * @param amountIn The total token amount in
     * @param maxAmountIn The amount of the limit that has been exceeded
     */
    error AmountInAboveMax(IERC20 tokenIn, uint256 amountIn, uint256 maxAmountIn);

    /**
     * @notice A hook adjusted amountIn exceeds the maximum limit specified for the operation.
     * @param tokenIn The incoming token
     * @param amountIn The total token amount in
     * @param maxAmountIn The amount of the limit that has been exceeded
     */
    error HookAdjustedAmountInAboveMax(IERC20 tokenIn, uint256 amountIn, uint256 maxAmountIn);

    /**
     * @notice The BPT amount received from adding liquidity is below the minimum specified for the operation.
     * @param amountOut The total BPT amount out
     * @param minAmountOut The amount of the limit that has been exceeded
     */
    error BptAmountOutBelowMin(uint256 amountOut, uint256 minAmountOut);

    /// @notice Pool does not support adding liquidity with a customized input.
    error DoesNotSupportAddLiquidityCustom();

    /// @notice Pool does not support adding liquidity through donation.
    error DoesNotSupportDonation();

    /*******************************************************************************
                                    Remove Liquidity
    *******************************************************************************/

    /// @notice Remove liquidity kind not supported.
    error InvalidRemoveLiquidityKind();

    /**
     * @notice The actual amount out is below the minimum limit specified for the operation.
     * @param tokenOut The outgoing token
     * @param amountOut The total BPT amount out
     * @param minAmountOut The amount of the limit that has been exceeded
     */
    error AmountOutBelowMin(IERC20 tokenOut, uint256 amountOut, uint256 minAmountOut);

    /**
     * @notice The hook adjusted amount out is below the minimum limit specified for the operation.
     * @param tokenOut The outgoing token
     * @param amountOut The total BPT amount out
     * @param minAmountOut The amount of the limit that has been exceeded
     */
    error HookAdjustedAmountOutBelowMin(IERC20 tokenOut, uint256 amountOut, uint256 minAmountOut);

    /**
     * @notice The required BPT amount in exceeds the maximum limit specified for the operation.
     * @param amountIn The total BPT amount in
     * @param maxAmountIn The amount of the limit that has been exceeded
     */
    error BptAmountInAboveMax(uint256 amountIn, uint256 maxAmountIn);

    /// @notice Pool does not support removing liquidity with a customized input.
    error DoesNotSupportRemoveLiquidityCustom();

    /*******************************************************************************
                                     Fees
    *******************************************************************************/

    /**
     * @notice Error raised when there is an overflow in the fee calculation.
     * @dev This occurs when the sum of the parts (aggregate swap or yield fee) is greater than the whole
     * (total swap or yield fee). Also validated when the protocol fee controller updates aggregate fee
     * percentages in the Vault.
     */
    error ProtocolFeesExceedTotalCollected();

    /**
     * @notice Error raised when the swap fee percentage is less than the minimum allowed value.
     * @dev The Vault itself does not impose a universal minimum. Rather, it validates against the
     * range specified by the `ISwapFeePercentageBounds` interface. and reverts with this error
     * if it is below the minimum value returned by the pool.
     *
     * Pools with dynamic fees do not check these limits.
     */
    error SwapFeePercentageTooLow();

    /**
     * @notice Error raised when the swap fee percentage is greater than the maximum allowed value.
     * @dev The Vault itself does not impose a universal minimum. Rather, it validates against the
     * range specified by the `ISwapFeePercentageBounds` interface. and reverts with this error
     * if it is above the maximum value returned by the pool.
     *
     * Pools with dynamic fees do not check these limits.
     */
    error SwapFeePercentageTooHigh();

    /**
     * @notice Primary fee percentages result in an aggregate fee that cannot be stored with the required precision.
     * @dev Primary fee percentages are 18-decimal values, stored here in 64 bits, and calculated with full 256-bit
     * precision. However, the resulting aggregate fees are stored in the Vault with 24-bit precision, which
     * corresponds to 0.00001% resolution (i.e., a fee can be 1%, 1.00001%, 1.00002%, but not 1.000005%).
     * Disallow setting fees such that there would be precision loss in the Vault, leading to a discrepancy between
     * the aggregate fee calculated here and that stored in the Vault.
     */
    error FeePrecisionTooHigh();

    /// @notice A given percentage is above the maximum (usually a value close to FixedPoint.ONE, or 1e18 wei).
    error PercentageAboveMax();

    /*******************************************************************************
                                    Queries
    *******************************************************************************/

    /// @notice A user tried to execute a query operation when they were disabled.
    error QueriesDisabled();

    /// @notice An admin tried to re-enable queries, but they were disabled permanently.
    error QueriesDisabledPermanently();

    /*******************************************************************************
                                Recovery Mode
    *******************************************************************************/

    /**
     * @notice Cannot enable recovery mode when already enabled.
     * @param pool The pool
     */
    error PoolInRecoveryMode(address pool);

    /**
     * @notice Cannot disable recovery mode when not enabled.
     * @param pool The pool
     */
    error PoolNotInRecoveryMode(address pool);

    /*******************************************************************************
                                Authentication
    *******************************************************************************/

    /**
     * @notice Error indicating the sender is not the Vault (e.g., someone is trying to call a permissioned function).
     * @param sender The account attempting to call a permissioned function
     */
    error SenderIsNotVault(address sender);

    /*******************************************************************************
                                        Pausing
    *******************************************************************************/

    /// @notice The caller specified a pause window period longer than the maximum.
    error VaultPauseWindowDurationTooLarge();

    /// @notice The caller specified a buffer period longer than the maximum.
    error PauseBufferPeriodDurationTooLarge();

    /// @notice A user tried to perform an operation while the Vault was paused.
    error VaultPaused();

    /// @notice Governance tried to unpause the Vault when it was not paused.
    error VaultNotPaused();

    /// @notice Governance tried to pause the Vault after the pause period expired.
    error VaultPauseWindowExpired();

    /**
     * @notice A user tried to perform an operation involving a paused Pool.
     * @param pool The paused pool
     */
    error PoolPaused(address pool);

    /**
     * @notice Governance tried to unpause the Pool when it was not paused.
     * @param pool The unpaused pool
     */
    error PoolNotPaused(address pool);

    /**
     * @notice Governance tried to pause a Pool after the pause period expired.
     * @param pool The pool
     */
    error PoolPauseWindowExpired(address pool);

    /*******************************************************************************
                                ERC4626 token buffers
    *******************************************************************************/

    /**
     * @notice The buffer for the given wrapped token was already initialized.
     * @param wrappedToken The wrapped token corresponding to the buffer
     */
    error BufferAlreadyInitialized(IERC4626 wrappedToken);

    /**
     * @notice The buffer for the given wrapped token was not initialized.
     * @param wrappedToken The wrapped token corresponding to the buffer
     */
    error BufferNotInitialized(IERC4626 wrappedToken);

    /// @notice The user is trying to remove more than their allocated shares from the buffer.
    error NotEnoughBufferShares();

    /**
     * @notice The wrapped token asset does not match the underlying token.
     * @dev This should never happen, but a malicious wrapper contract might not return the correct address.
     * Legitimate wrapper contracts should make the asset a constant or immutable value.
     *
     * @param wrappedToken The wrapped token corresponding to the buffer
     * @param underlyingToken The underlying token returned by `asset`
     */
    error WrongUnderlyingToken(IERC4626 wrappedToken, address underlyingToken);

    /**
     * @notice A wrapped token reported the zero address as its underlying token asset.
     * @dev This should never happen, but a malicious wrapper contract might do this (e.g., in an attempt to
     * re-initialize the buffer).
     *
     * @param wrappedToken The wrapped token corresponding to the buffer
     */
    error InvalidUnderlyingToken(IERC4626 wrappedToken);

    /**
     * @notice The amount given to wrap/unwrap was too small, which can introduce rounding issues.
     * @param wrappedToken The wrapped token corresponding to the buffer
     */
    error WrapAmountTooSmall(IERC4626 wrappedToken);

    /// @notice Buffer operation attempted while vault buffers are paused.
    error VaultBuffersArePaused();

    /// @notice Buffer shares were minted to the zero address.
    error BufferSharesInvalidReceiver();

    /// @notice Buffer shares were burned from the zero address.
    error BufferSharesInvalidOwner();

    /**
     * @notice The total supply of a buffer can't be lower than the absolute minimum.
     * @param totalSupply The total supply value that was below the minimum
     */
    error BufferTotalSupplyTooLow(uint256 totalSupply);

    /// @dev A wrap/unwrap operation consumed more or returned less underlying tokens than it should.
    error NotEnoughUnderlying(IERC4626 wrappedToken, uint256 expectedUnderlyingAmount, uint256 actualUnderlyingAmount);

    /// @dev A wrap/unwrap operation consumed more or returned less wrapped tokens than it should.
    error NotEnoughWrapped(IERC4626 wrappedToken, uint256 expectedWrappedAmount, uint256 actualWrappedAmount);

    /// @dev Shares issued during initialization are below the requested amount.
    error IssuedSharesBelowMin(uint256 issuedShares, uint256 minIssuedShares);

    /*******************************************************************************
                                    Miscellaneous
    *******************************************************************************/

    /// @notice Pool does not support adding / removing liquidity with an unbalanced input.
    error DoesNotSupportUnbalancedLiquidity();

    /// @notice The contract should not receive ETH.
    error CannotReceiveEth();

    /**
     * @notice The `VaultExtension` contract was called by an account directly.
     * @dev It can only be called by the Vault via delegatecall.
     */
    error NotVaultDelegateCall();

    /// @notice The `VaultExtension` contract was configured with an incorrect Vault address.
    error WrongVaultExtensionDeployment();

    /// @notice The `ProtocolFeeController` contract was configured with an incorrect Vault address.
    error WrongProtocolFeeControllerDeployment();

    /// @notice The `VaultAdmin` contract was configured with an incorrect Vault address.
    error WrongVaultAdminDeployment();

    /// @notice Quote reverted with a reserved error code.
    error QuoteResultSpoofed();
}


// File: @balancer-labs/v3-interfaces/contracts/vault/IVaultEvents.sol

// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.24;

import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { IProtocolFeeController } from "./IProtocolFeeController.sol";
import { IAuthorizer } from "./IAuthorizer.sol";
import { IHooks } from "./IHooks.sol";
import "./VaultTypes.sol";

/// @dev Events are declared inside an interface (namespace) to improve DX with Typechain.
interface IVaultEvents {
    /**
     * @notice A Pool was registered by calling `registerPool`.
     * @param pool The pool being registered
     * @param factory The factory creating the pool
     * @param tokenConfig An array of descriptors for the tokens the pool will manage
     * @param swapFeePercentage The static swap fee of the pool
     * @param pauseWindowEndTime The pool's pause window end time
     * @param roleAccounts Addresses the Vault will allow to change certain pool settings
     * @param hooksConfig Flags indicating which hooks the pool supports and address of hooks contract
     * @param liquidityManagement Supported liquidity management hook flags
     */
    event PoolRegistered(
        address indexed pool,
        address indexed factory,
        TokenConfig[] tokenConfig,
        uint256 swapFeePercentage,
        uint32 pauseWindowEndTime,
        PoolRoleAccounts roleAccounts,
        HooksConfig hooksConfig,
        LiquidityManagement liquidityManagement
    );

    /**
     * @notice A Pool was initialized by calling `initialize`.
     * @param pool The pool being initialized
     */
    event PoolInitialized(address indexed pool);

    /**
     * @notice A swap has occurred.
     * @param pool The pool with the tokens being swapped
     * @param tokenIn The token entering the Vault (balance increases)
     * @param tokenOut The token leaving the Vault (balance decreases)
     * @param amountIn Number of tokenIn tokens
     * @param amountOut Number of tokenOut tokens
     * @param swapFeePercentage Swap fee percentage applied (can differ if dynamic)
     * @param swapFeeAmount Swap fee amount paid
     */
    event Swap(
        address indexed pool,
        IERC20 indexed tokenIn,
        IERC20 indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        uint256 swapFeePercentage,
        uint256 swapFeeAmount
    );

    /**
     * @notice A wrap operation has occurred.
     * @param wrappedToken The wrapped token address
     * @param depositedUnderlying Number of underlying tokens deposited
     * @param mintedShares Number of shares (wrapped tokens) minted
     * @param bufferBalances The final buffer balances, packed in 128-bit words (underlying, wrapped)
     */
    event Wrap(
        IERC4626 indexed wrappedToken,
        uint256 depositedUnderlying,
        uint256 mintedShares,
        bytes32 bufferBalances
    );

    /**
     * @notice An unwrap operation has occurred.
     * @param wrappedToken The wrapped token address
     * @param burnedShares Number of shares (wrapped tokens) burned
     * @param withdrawnUnderlying Number of underlying tokens withdrawn
     * @param bufferBalances The final buffer balances, packed in 128-bit words (underlying, wrapped)
     */
    event Unwrap(
        IERC4626 indexed wrappedToken,
        uint256 burnedShares,
        uint256 withdrawnUnderlying,
        bytes32 bufferBalances
    );

    /**
     * @notice Liquidity has been added to a pool (including initialization).
     * @param pool The pool with liquidity added
     * @param liquidityProvider The user performing the operation
     * @param kind The add liquidity operation type (e.g., proportional, custom)
     * @param totalSupply The total supply of the pool after the operation
     * @param amountsAddedRaw The amount of each token that was added, sorted in token registration order
     * @param swapFeeAmountsRaw The total swap fees charged, sorted in token registration order
     */
    event LiquidityAdded(
        address indexed pool,
        address indexed liquidityProvider,
        AddLiquidityKind indexed kind,
        uint256 totalSupply,
        uint256[] amountsAddedRaw,
        uint256[] swapFeeAmountsRaw
    );

    /**
     * @notice Liquidity has been removed from a pool.
     * @param pool The pool with liquidity removed
     * @param liquidityProvider The user performing the operation
     * @param kind The remove liquidity operation type (e.g., proportional, custom)
     * @param totalSupply The total supply of the pool after the operation
     * @param amountsRemovedRaw The amount of each token that was removed, sorted in token registration order
     * @param swapFeeAmountsRaw The total swap fees charged, sorted in token registration order
     */
    event LiquidityRemoved(
        address indexed pool,
        address indexed liquidityProvider,
        RemoveLiquidityKind indexed kind,
        uint256 totalSupply,
        uint256[] amountsRemovedRaw,
        uint256[] swapFeeAmountsRaw
    );

    /**
     * @notice The Vault's pause status has changed.
     * @param paused True if the Vault was paused
     */
    event VaultPausedStateChanged(bool paused);

    /// @notice `disableQuery` has been called on the Vault, disabling query functionality.
    event VaultQueriesDisabled();

    /// @notice `enableQuery` has been called on the Vault, enabling query functionality.
    event VaultQueriesEnabled();

    /**
     * @notice A Pool's pause status has changed.
     * @param pool The pool that was just paused or unpaused
     * @param paused True if the pool was paused
     */
    event PoolPausedStateChanged(address indexed pool, bool paused);

    /**
     * @notice Emitted when the swap fee percentage of a pool is updated.
     * @param swapFeePercentage The new swap fee percentage for the pool
     */
    event SwapFeePercentageChanged(address indexed pool, uint256 swapFeePercentage);

    /**
     * @notice Recovery mode has been enabled or disabled for a pool.
     * @param pool The pool
     * @param recoveryMode True if recovery mode was enabled
     */
    event PoolRecoveryModeStateChanged(address indexed pool, bool recoveryMode);

    /**
     * @notice A protocol or pool creator fee has changed, causing an update to the aggregate swap fee.
     * @dev The `ProtocolFeeController` will emit an event with the underlying change.
     * @param pool The pool whose aggregate swap fee percentage changed
     * @param aggregateSwapFeePercentage The new aggregate swap fee percentage
     */
    event AggregateSwapFeePercentageChanged(address indexed pool, uint256 aggregateSwapFeePercentage);

    /**
     * @notice A protocol or pool creator fee has changed, causing an update to the aggregate yield fee.
     * @dev The `ProtocolFeeController` will emit an event with the underlying change.
     * @param pool The pool whose aggregate yield fee percentage changed
     * @param aggregateYieldFeePercentage The new aggregate yield fee percentage
     */
    event AggregateYieldFeePercentageChanged(address indexed pool, uint256 aggregateYieldFeePercentage);

    /**
     * @notice A new authorizer is set by `setAuthorizer`.
     * @param newAuthorizer The address of the new authorizer
     */
    event AuthorizerChanged(IAuthorizer indexed newAuthorizer);

    /**
     * @notice A new protocol fee controller is set by `setProtocolFeeController`.
     * @param newProtocolFeeController The address of the new protocol fee controller
     */
    event ProtocolFeeControllerChanged(IProtocolFeeController indexed newProtocolFeeController);

    /**
     * @notice Liquidity was added to an ERC4626 buffer corresponding to the given wrapped token.
     * @dev The underlying token can be derived from the wrapped token, so it's not included here.
     *
     * @param wrappedToken The wrapped token that identifies the buffer
     * @param amountUnderlying The amount of the underlying token that was deposited
     * @param amountWrapped The amount of the wrapped token that was deposited
     * @param bufferBalances The final buffer balances, packed in 128-bit words (underlying, wrapped)
     */
    event LiquidityAddedToBuffer(
        IERC4626 indexed wrappedToken,
        uint256 amountUnderlying,
        uint256 amountWrapped,
        bytes32 bufferBalances
    );

    /**
     * @notice Buffer shares were minted for an ERC4626 buffer corresponding to a given wrapped token.
     * @dev The shares are not tokenized like pool BPT, but accounted for in the Vault. `getBufferOwnerShares`
     * retrieves the current total shares for a given buffer and address, and `getBufferTotalShares` returns the
     * "totalSupply" of a buffer.
     *
     * @param wrappedToken The wrapped token that identifies the buffer
     * @param to The owner of the minted shares
     * @param issuedShares The amount of "internal BPT" shares created
     */
    event BufferSharesMinted(IERC4626 indexed wrappedToken, address indexed to, uint256 issuedShares);

    /**
     * @notice Buffer shares were burned for an ERC4626 buffer corresponding to a given wrapped token.
     * @dev The shares are not tokenized like pool BPT, but accounted for in the Vault. `getBufferOwnerShares`
     * retrieves the current total shares for a given buffer and address, and `getBufferTotalShares` returns the
     * "totalSupply" of a buffer.
     *
     * @param wrappedToken The wrapped token that identifies the buffer
     * @param from The owner of the burned shares
     * @param burnedShares The amount of "internal BPT" shares burned
     */
    event BufferSharesBurned(IERC4626 indexed wrappedToken, address indexed from, uint256 burnedShares);

    /**
     * @notice Liquidity was removed from an ERC4626 buffer.
     * @dev The underlying token can be derived from the wrapped token, so it's not included here.
     * @param wrappedToken The wrapped token that identifies the buffer
     * @param amountUnderlying The amount of the underlying token that was withdrawn
     * @param amountWrapped The amount of the wrapped token that was withdrawn
     * @param bufferBalances The final buffer balances, packed in 128-bit words (underlying, wrapped)
     */
    event LiquidityRemovedFromBuffer(
        IERC4626 indexed wrappedToken,
        uint256 amountUnderlying,
        uint256 amountWrapped,
        bytes32 bufferBalances
    );

    /**
     * @notice The Vault buffers pause status has changed.
     * @dev If buffers all paused, all buffer operations (i.e., all calls through the Router with `isBuffer`
     * set to true) will revert.
     *
     * @param paused True if the Vault buffers were paused
     */
    event VaultBuffersPausedStateChanged(bool paused);

    /**
     * @notice Pools can use this event to emit event data from the Vault.
     * @param pool Pool address
     * @param eventKey Event key
     * @param eventData Encoded event data
     */
    event VaultAuxiliary(address indexed pool, bytes32 indexed eventKey, bytes eventData);
}


// File: @balancer-labs/v3-interfaces/contracts/vault/IVaultExtension.sol

// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.24;

import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { IAuthorizer } from "./IAuthorizer.sol";
import { IProtocolFeeController } from "./IProtocolFeeController.sol";
import { IVault } from "./IVault.sol";
import { IHooks } from "./IHooks.sol";
import "./VaultTypes.sol";

/**
 * @notice Interface for functions defined on the `VaultExtension` contract.
 * @dev `VaultExtension` handles less critical or frequently used functions, since delegate calls through
 * the Vault are more expensive than direct calls. The main Vault contains the core code for swaps and
 * liquidity operations.
 */
interface IVaultExtension {
    /*******************************************************************************
                              Constants and immutables
    *******************************************************************************/

    /**
     * @notice Returns the main Vault address.
     * @dev The main Vault contains the entrypoint and main liquidity operation implementations.
     * @return vault The address of the main Vault
     */
    function vault() external view returns (IVault);

    /**
     * @notice Returns the VaultAdmin contract address.
     * @dev The VaultAdmin contract mostly implements permissioned functions.
     * @return vaultAdmin The address of the Vault admin
     */
    function getVaultAdmin() external view returns (address vaultAdmin);

    /*******************************************************************************
                              Transient Accounting
    *******************************************************************************/

    /**
     * @notice Returns whether the Vault is unlocked (i.e., executing an operation).
     * @dev The Vault must be unlocked to perform state-changing liquidity operations.
     * @return unlocked True if the Vault is unlocked, false otherwise
     */
    function isUnlocked() external view returns (bool unlocked);

    /**
     *  @notice Returns the count of non-zero deltas.
     *  @return nonzeroDeltaCount The current value of `_nonzeroDeltaCount`
     */
    function getNonzeroDeltaCount() external view returns (uint256 nonzeroDeltaCount);

    /**
     * @notice Retrieves the token delta for a specific token.
     * @dev This function allows reading the value from the `_tokenDeltas` mapping.
     * @param token The token for which the delta is being fetched
     * @return tokenDelta The delta of the specified token
     */
    function getTokenDelta(IERC20 token) external view returns (int256 tokenDelta);

    /**
     * @notice Retrieves the reserve (i.e., total Vault balance) of a given token.
     * @param token The token for which to retrieve the reserve
     * @return reserveAmount The amount of reserves for the given token
     */
    function getReservesOf(IERC20 token) external view returns (uint256 reserveAmount);

    /**
     * @notice This flag is used to detect and tax "round-trip" interactions (adding and removing liquidity in the
     * same pool).
     * @dev Taxing remove liquidity proportional whenever liquidity was added in the same `unlock` call adds an extra
     * layer of security, discouraging operations that try to undo others for profit. Remove liquidity proportional
     * is the only standard way to exit a position without fees, and this flag is used to enable fees in that case.
     * It also discourages indirect swaps via unbalanced add and remove proportional, as they are expected to be worse
     * than a simple swap for every pool type.
     *
     * @param pool Address of the pool to check
     * @return liquidityAdded True if liquidity has been added to this pool in the current transaction
     
     * Note that there is no `sessionId` argument; it always returns the value for the current (i.e., latest) session.
     */
    function getAddLiquidityCalledFlag(address pool) external view returns (bool liquidityAdded);

    /*******************************************************************************
                                    Pool Registration
    *******************************************************************************/

    /**
     * @notice Registers a pool, associating it with its factory and the tokens it manages.
     * @dev A pool can opt-out of pausing by providing a zero value for the pause window, or allow pausing indefinitely
     * by providing a large value. (Pool pause windows are not limited by the Vault maximums.) The vault defines an
     * additional buffer period during which a paused pool will stay paused. After the buffer period passes, a paused
     * pool will automatically unpause. Balancer timestamps are 32 bits.
     *
     * A pool can opt out of Balancer governance pausing by providing a custom `pauseManager`. This might be a
     * multi-sig contract or an arbitrary smart contract with its own access controls, that forwards calls to
     * the Vault.
     *
     * If the zero address is provided for the `pauseManager`, permissions for pausing the pool will default to the
     * authorizer.
     *
     * @param pool The address of the pool being registered
     * @param tokenConfig An array of descriptors for the tokens the pool will manage
     * @param swapFeePercentage The initial static swap fee percentage of the pool
     * @param pauseWindowEndTime The timestamp after which it is no longer possible to pause the pool
     * @param protocolFeeExempt If true, the pool's initial aggregate fees will be set to 0
     * @param roleAccounts Addresses the Vault will allow to change certain pool settings
     * @param poolHooksContract Contract that implements the hooks for the pool
     * @param liquidityManagement Liquidity management flags with implemented methods
     */
    function registerPool(
        address pool,
        TokenConfig[] memory tokenConfig,
        uint256 swapFeePercentage,
        uint32 pauseWindowEndTime,
        bool protocolFeeExempt,
        PoolRoleAccounts calldata roleAccounts,
        address poolHooksContract,
        LiquidityManagement calldata liquidityManagement
    ) external;

    /**
     * @notice Checks whether a pool is registered.
     * @param pool Address of the pool to check
     * @return registered True if the pool is registered, false otherwise
     */
    function isPoolRegistered(address pool) external view returns (bool registered);

    /**
     * @notice Initializes a registered pool by adding liquidity; mints BPT tokens for the first time in exchange.
     * @param pool Address of the pool to initialize
     * @param to Address that will receive the output BPT
     * @param tokens Tokens used to seed the pool (must match the registered tokens)
     * @param exactAmountsIn Exact amounts of input tokens
     * @param minBptAmountOut Minimum amount of output pool tokens
     * @param userData Additional (optional) data required for adding initial liquidity
     * @return bptAmountOut Output pool token amount
     */
    function initialize(
        address pool,
        address to,
        IERC20[] memory tokens,
        uint256[] memory exactAmountsIn,
        uint256 minBptAmountOut,
        bytes memory userData
    ) external returns (uint256 bptAmountOut);

    /*******************************************************************************
                                    Pool Information
    *******************************************************************************/

    /**
     * @notice Checks whether a pool is initialized.
     * @dev An initialized pool can be considered registered as well.
     * @param pool Address of the pool to check
     * @return initialized True if the pool is initialized, false otherwise
     */
    function isPoolInitialized(address pool) external view returns (bool initialized);

    /**
     * @notice Gets the tokens registered to a pool.
     * @param pool Address of the pool
     * @return tokens List of tokens in the pool
     */
    function getPoolTokens(address pool) external view returns (IERC20[] memory tokens);

    /**
     * @notice Gets pool token rates.
     * @dev This function performs external calls if tokens are yield-bearing. All returned arrays are in token
     * registration order.
     *
     * @param pool Address of the pool
     * @return decimalScalingFactors Conversion factor used to adjust for token decimals for uniform precision in
     * calculations. FP(1) for 18-decimal tokens
     * @return tokenRates 18-decimal FP values for rate tokens (e.g., yield-bearing), or FP(1) for standard tokens
     */
    function getPoolTokenRates(
        address pool
    ) external view returns (uint256[] memory decimalScalingFactors, uint256[] memory tokenRates);

    /**
     * @notice Returns comprehensive pool data for the given pool.
     * @dev This contains the pool configuration (flags), tokens and token types, rates, scaling factors, and balances.
     * @param pool The address of the pool
     * @return poolData The `PoolData` result
     */
    function getPoolData(address pool) external view returns (PoolData memory poolData);

    /**
     * @notice Gets the raw data for a pool: tokens, raw balances, scaling factors.
     * @param pool Address of the pool
     * @return tokens The pool tokens, sorted in registration order
     * @return tokenInfo Token info structs (type, rate provider, yield flag), sorted in token registration order
     * @return balancesRaw Current native decimal balances of the pool tokens, sorted in token registration order
     * @return lastBalancesLiveScaled18 Last saved live balances, sorted in token registration order
     */
    function getPoolTokenInfo(
        address pool
    )
        external
        view
        returns (
            IERC20[] memory tokens,
            TokenInfo[] memory tokenInfo,
            uint256[] memory balancesRaw,
            uint256[] memory lastBalancesLiveScaled18
        );

    /**
     * @notice Gets current live balances of a given pool (fixed-point, 18 decimals), corresponding to its tokens in
     * registration order.
     *
     * @param pool Address of the pool
     * @return balancesLiveScaled18 Token balances after paying yield fees, applying decimal scaling and rates
     */
    function getCurrentLiveBalances(address pool) external view returns (uint256[] memory balancesLiveScaled18);

    /**
     * @notice Gets the configuration parameters of a pool.
     * @dev The `PoolConfig` contains liquidity management and other state flags, fee percentages, the pause window.
     * @param pool Address of the pool
     * @return poolConfig The pool configuration as a `PoolConfig` struct
     */
    function getPoolConfig(address pool) external view returns (PoolConfig memory poolConfig);

    /**
     * @notice Gets the hooks configuration parameters of a pool.
     * @dev The `HooksConfig` contains flags indicating which pool hooks are implemented.
     * @param pool Address of the pool
     * @return hooksConfig The hooks configuration as a `HooksConfig` struct
     */
    function getHooksConfig(address pool) external view returns (HooksConfig memory hooksConfig);

    /**
     * @notice The current rate of a pool token (BPT) = invariant / totalSupply.
     * @param pool Address of the pool
     * @return rate BPT rate
     */
    function getBptRate(address pool) external view returns (uint256 rate);

    /*******************************************************************************
                                 Balancer Pool Tokens
    *******************************************************************************/

    /**
     * @notice Gets the total supply of a given ERC20 token.
     * @param token The token address
     * @return tokenTotalSupply Total supply of the token
     */
    function totalSupply(address token) external view returns (uint256 tokenTotalSupply);

    /**
     * @notice Gets the balance of an account for a given ERC20 token.
     * @param token Address of the token
     * @param account Address of the account
     * @return tokenBalance Token balance of the account
     */
    function balanceOf(address token, address account) external view returns (uint256 tokenBalance);

    /**
     * @notice Gets the allowance of a spender for a given ERC20 token and owner.
     * @param token Address of the token
     * @param owner Address of the owner
     * @param spender Address of the spender
     * @return tokenAllowance Amount of tokens the spender is allowed to spend
     */
    function allowance(address token, address owner, address spender) external view returns (uint256 tokenAllowance);

    /**
     * @notice Approves a spender to spend pool tokens on behalf of sender.
     * @dev Notice that the pool token address is not included in the params. This function is exclusively called by
     * the pool contract, so msg.sender is used as the token address.
     *
     * @param owner Address of the owner
     * @param spender Address of the spender
     * @param amount Amount of tokens to approve
     * @return success True if successful, false otherwise
     */
    function approve(address owner, address spender, uint256 amount) external returns (bool success);

    /*******************************************************************************
                                     Pool Pausing
    *******************************************************************************/

    /**
     * @notice Indicates whether a pool is paused.
     * @dev If a pool is paused, all non-Recovery Mode state-changing operations will revert.
     * @param pool The pool to be checked
     * @return poolPaused True if the pool is paused
     */
    function isPoolPaused(address pool) external view returns (bool poolPaused);

    /**
     * @notice Returns the paused status, and end times of the Pool's pause window and buffer period.
     * @dev Note that even when set to a paused state, the pool will automatically unpause at the end of
     * the buffer period. Balancer timestamps are 32 bits.
     *
     * @param pool The pool whose data is requested
     * @return poolPaused True if the Pool is paused
     * @return poolPauseWindowEndTime The timestamp of the end of the Pool's pause window
     * @return poolBufferPeriodEndTime The timestamp after which the Pool unpauses itself (if paused)
     * @return pauseManager The pause manager, or the zero address
     */
    function getPoolPausedState(
        address pool
    )
        external
        view
        returns (bool poolPaused, uint32 poolPauseWindowEndTime, uint32 poolBufferPeriodEndTime, address pauseManager);

    /*******************************************************************************
                                   ERC4626 Buffers
    *******************************************************************************/

    /**
     * @notice Checks if the wrapped token has an initialized buffer in the Vault.
     * @dev An initialized buffer should have an asset registered in the Vault.
     * @param wrappedToken Address of the wrapped token that implements IERC4626
     * @return isBufferInitialized True if the ERC4626 buffer is initialized
     */
    function isERC4626BufferInitialized(IERC4626 wrappedToken) external view returns (bool isBufferInitialized);

    /**
     * @notice Gets the registered asset for a given buffer.
     * @dev To avoid malicious wrappers (e.g., that might potentially change their asset after deployment), routers
     * should never call `wrapper.asset()` directly, at least without checking it against the asset registered with
     * the Vault on initialization.
     *
     * @param wrappedToken The wrapped token specifying the buffer
     * @return asset The underlying asset of the wrapped token
     */
    function getERC4626BufferAsset(IERC4626 wrappedToken) external view returns (address asset);

    /*******************************************************************************
                                          Fees
    *******************************************************************************/

    /**
     * @notice Returns the accumulated swap fees (including aggregate fees) in `token` collected by the pool.
     * @param pool The address of the pool for which aggregate fees have been collected
     * @param token The address of the token in which fees have been accumulated
     * @return swapFeeAmount The total amount of fees accumulated in the specified token
     */
    function getAggregateSwapFeeAmount(address pool, IERC20 token) external view returns (uint256 swapFeeAmount);

    /**
     * @notice Returns the accumulated yield fees (including aggregate fees) in `token` collected by the pool.
     * @param pool The address of the pool for which aggregate fees have been collected
     * @param token The address of the token in which fees have been accumulated
     * @return yieldFeeAmount The total amount of fees accumulated in the specified token
     */
    function getAggregateYieldFeeAmount(address pool, IERC20 token) external view returns (uint256 yieldFeeAmount);

    /**
     * @notice Fetches the static swap fee percentage for a given pool.
     * @param pool The address of the pool whose static swap fee percentage is being queried
     * @return swapFeePercentage The current static swap fee percentage for the specified pool
     */
    function getStaticSwapFeePercentage(address pool) external view returns (uint256 swapFeePercentage);

    /**
     * @notice Fetches the role accounts for a given pool (pause manager, swap manager, pool creator)
     * @param pool The address of the pool whose roles are being queried
     * @return roleAccounts A struct containing the role accounts for the pool (or 0 if unassigned)
     */
    function getPoolRoleAccounts(address pool) external view returns (PoolRoleAccounts memory roleAccounts);

    /**
     * @notice Query the current dynamic swap fee percentage of a pool, given a set of swap parameters.
     * @dev Reverts if the hook doesn't return the success flag set to `true`.
     * @param pool The pool
     * @param swapParams The swap parameters used to compute the fee
     * @return dynamicSwapFeePercentage The dynamic swap fee percentage
     */
    function computeDynamicSwapFeePercentage(
        address pool,
        PoolSwapParams memory swapParams
    ) external view returns (uint256 dynamicSwapFeePercentage);

    /**
     * @notice Returns the Protocol Fee Controller address.
     * @return protocolFeeController Address of the ProtocolFeeController
     */
    function getProtocolFeeController() external view returns (IProtocolFeeController protocolFeeController);

    /*******************************************************************************
                                     Recovery Mode
    *******************************************************************************/

    /**
     * @notice Checks whether a pool is in Recovery Mode.
     * @dev Recovery Mode enables a safe proportional withdrawal path, with no external calls.
     * @param pool Address of the pool to check
     * @return inRecoveryMode True if the pool is in Recovery Mode, false otherwise
     */
    function isPoolInRecoveryMode(address pool) external view returns (bool inRecoveryMode);

    /**
     * @notice Remove liquidity from a pool specifying exact pool tokens in, with proportional token amounts out.
     * The request is implemented by the Vault without any interaction with the pool, ensuring that
     * it works the same for all pools, and cannot be disabled by a new pool type.
     *
     * @param pool Address of the pool
     * @param from Address of user to burn pool tokens from
     * @param exactBptAmountIn Input pool token amount
     * @param minAmountsOut Minimum amounts of tokens to be received, sorted in token registration order
     * @return amountsOut Actual calculated amounts of output tokens, sorted in token registration order
     */
    function removeLiquidityRecovery(
        address pool,
        address from,
        uint256 exactBptAmountIn,
        uint256[] memory minAmountsOut
    ) external returns (uint256[] memory amountsOut);

    /*******************************************************************************
                                    Queries
    *******************************************************************************/

    /**
     * @notice Performs a callback on msg.sender with arguments provided in `data`.
     * @dev Used to query a set of operations on the Vault. Only off-chain eth_call are allowed,
     * anything else will revert.
     *
     * Allows querying any operation on the Vault that has the `onlyWhenUnlocked` modifier.
     *
     * Allows the external calling of a function via the Vault contract to
     * access Vault's functions guarded by `onlyWhenUnlocked`.
     * `transient` modifier ensuring balances changes within the Vault are settled.
     *
     * @param data Contains function signature and args to be passed to the msg.sender
     * @return result Resulting data from the call
     */
    function quote(bytes calldata data) external returns (bytes memory result);

    /**
     * @notice Performs a callback on msg.sender with arguments provided in `data`.
     * @dev Used to query a set of operations on the Vault. Only off-chain eth_call are allowed,
     * anything else will revert.
     *
     * Allows querying any operation on the Vault that has the `onlyWhenUnlocked` modifier.
     *
     * Allows the external calling of a function via the Vault contract to
     * access Vault's functions guarded by `onlyWhenUnlocked`.
     * `transient` modifier ensuring balances changes within the Vault are settled.
     *
     * This call always reverts, returning the result in the revert reason.
     *
     * @param data Contains function signature and args to be passed to the msg.sender
     */
    function quoteAndRevert(bytes calldata data) external;

    /**
     * @notice Returns true if queries are disabled on the Vault.
     * @dev If true, queries might either be disabled temporarily or permanently.
     * @return queryDisabled True if query functionality is reversibly disabled
     */
    function isQueryDisabled() external view returns (bool queryDisabled);

    /**
     * @notice Returns true if queries are disabled permanently; false if they are enabled.
     * @dev This is a one-way switch. Once queries are disabled permanently, they can never be re-enabled.
     * @return queryDisabledPermanently True if query functionality is permanently disabled
     */
    function isQueryDisabledPermanently() external view returns (bool queryDisabledPermanently);

    /**
     * @notice Pools can use this event to emit event data from the Vault.
     * @param eventKey Event key
     * @param eventData Encoded event data
     */
    function emitAuxiliaryEvent(bytes32 eventKey, bytes calldata eventData) external;

    /*******************************************************************************
                                Authentication
    *******************************************************************************/

    /**
     * @notice Returns the Authorizer address.
     * @dev The authorizer holds the permissions granted by governance. It is set on Vault deployment,
     * and can be changed through a permissioned call.
     *
     * @return authorizer Address of the authorizer contract
     */
    function getAuthorizer() external view returns (IAuthorizer authorizer);
}


// File: @balancer-labs/v3-interfaces/contracts/vault/IVaultMain.sol

// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.24;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./VaultTypes.sol";

/**
 * @notice Interface for functions defined on the main Vault contract.
 * @dev These are generally "critical path" functions (swap, add/remove liquidity) that are in the main contract
 * for technical or performance reasons.
 */
interface IVaultMain {
    /*******************************************************************************
                              Transient Accounting
    *******************************************************************************/

    /**
     * @notice Creates a context for a sequence of operations (i.e., "unlocks" the Vault).
     * @dev Performs a callback on msg.sender with arguments provided in `data`. The Callback is `transient`,
     * meaning all balances for the caller have to be settled at the end.
     *
     * @param data Contains function signature and args to be passed to the msg.sender
     * @return result Resulting data from the call
     */
    function unlock(bytes calldata data) external returns (bytes memory result);

    /**
     * @notice Settles deltas for a token; must be successful for the current lock to be released.
     * @dev Protects the caller against leftover dust in the Vault for the token being settled. The caller
     * should know in advance how many tokens were paid to the Vault, so it can provide it as a hint to discard any
     * excess in the Vault balance.
     *
     * If the given hint is equal to or higher than the difference in reserves, the difference in reserves is given as
     * credit to the caller. If it's higher, the caller sent fewer tokens than expected, so settlement would fail.
     *
     * If the given hint is lower than the difference in reserves, the hint is given as credit to the caller.
     * In this case, the excess would be absorbed by the Vault (and reflected correctly in the reserves), but would
     * not affect settlement.
     *
     * The credit supplied by the Vault can be calculated as `min(reserveDifference, amountHint)`, where the reserve
     * difference equals current balance of the token minus existing reserves of the token when the function is called.
     *
     * @param token Address of the token
     * @param amountHint Amount paid as reported by the caller
     * @return credit Credit received in return of the payment
     */
    function settle(IERC20 token, uint256 amountHint) external returns (uint256 credit);

    /**
     * @notice Sends tokens to a recipient.
     * @dev There is no inverse operation for this function. Transfer funds to the Vault and call `settle` to cancel
     * debts.
     *
     * @param token Address of the token
     * @param to Recipient address
     * @param amount Amount of tokens to send
     */
    function sendTo(IERC20 token, address to, uint256 amount) external;

    /***************************************************************************
                                       Swaps
    ***************************************************************************/

    /**
     * @notice Swaps tokens based on provided parameters.
     * @dev All parameters are given in raw token decimal encoding.
     * @param vaultSwapParams Parameters for the swap (see above for struct definition)
     * @return amountCalculatedRaw Calculated swap amount
     * @return amountInRaw Amount of input tokens for the swap
     * @return amountOutRaw Amount of output tokens from the swap
     */
    function swap(
        VaultSwapParams memory vaultSwapParams
    ) external returns (uint256 amountCalculatedRaw, uint256 amountInRaw, uint256 amountOutRaw);

    /***************************************************************************
                                   Add Liquidity
    ***************************************************************************/

    /**
     * @notice Adds liquidity to a pool.
     * @dev Caution should be exercised when adding liquidity because the Vault has the capability
     * to transfer tokens from any user, given that it holds all allowances.
     *
     * @param params Parameters for the add liquidity (see above for struct definition)
     * @return amountsIn Actual amounts of input tokens
     * @return bptAmountOut Output pool token amount
     * @return returnData Arbitrary (optional) data with an encoded response from the pool
     */
    function addLiquidity(
        AddLiquidityParams memory params
    ) external returns (uint256[] memory amountsIn, uint256 bptAmountOut, bytes memory returnData);

    /***************************************************************************
                                 Remove Liquidity
    ***************************************************************************/

    /**
     * @notice Removes liquidity from a pool.
     * @dev Trusted routers can burn pool tokens belonging to any user and require no prior approval from the user.
     * Untrusted routers require prior approval from the user. This is the only function allowed to call
     * _queryModeBalanceIncrease (and only in a query context).
     *
     * @param params Parameters for the remove liquidity (see above for struct definition)
     * @return bptAmountIn Actual amount of BPT burned
     * @return amountsOut Actual amounts of output tokens
     * @return returnData Arbitrary (optional) data with an encoded response from the pool
     */
    function removeLiquidity(
        RemoveLiquidityParams memory params
    ) external returns (uint256 bptAmountIn, uint256[] memory amountsOut, bytes memory returnData);

    /*******************************************************************************
                                    Pool Information
    *******************************************************************************/

    /**
     * @notice Gets the index of a token in a given pool.
     * @dev Reverts if the pool is not registered, or if the token does not belong to the pool.
     * @param pool Address of the pool
     * @param token Address of the token
     * @return tokenCount Number of tokens in the pool
     * @return index Index corresponding to the given token in the pool's token list
     */
    function getPoolTokenCountAndIndexOfToken(
        address pool,
        IERC20 token
    ) external view returns (uint256 tokenCount, uint256 index);

    /*******************************************************************************
                                 Balancer Pool Tokens
    *******************************************************************************/

    /**
     * @notice Transfers pool token from owner to a recipient.
     * @dev Notice that the pool token address is not included in the params. This function is exclusively called by
     * the pool contract, so msg.sender is used as the token address.
     *
     * @param owner Address of the owner
     * @param to Address of the recipient
     * @param amount Amount of tokens to transfer
     * @return success True if successful, false otherwise
     */
    function transfer(address owner, address to, uint256 amount) external returns (bool);

    /**
     * @notice Transfers pool token from a sender to a recipient using an allowance.
     * @dev Notice that the pool token address is not included in the params. This function is exclusively called by
     * the pool contract, so msg.sender is used as the token address.
     *
     * @param spender Address allowed to perform the transfer
     * @param from Address of the sender
     * @param to Address of the recipient
     * @param amount Amount of tokens to transfer
     * @return success True if successful, false otherwise
     */
    function transferFrom(address spender, address from, address to, uint256 amount) external returns (bool success);

    /*******************************************************************************
                                  ERC4626 Buffers
    *******************************************************************************/

    /**
     * @notice Wraps/unwraps tokens based on the parameters provided.
     * @dev All parameters are given in raw token decimal encoding. It requires the buffer to be initialized,
     * and uses the internal wrapped token buffer when it has enough liquidity to avoid external calls.
     *
     * @param params Parameters for the wrap/unwrap operation (see struct definition)
     * @return amountCalculatedRaw Calculated swap amount
     * @return amountInRaw Amount of input tokens for the swap
     * @return amountOutRaw Amount of output tokens from the swap
     */
    function erc4626BufferWrapOrUnwrap(
        BufferWrapOrUnwrapParams memory params
    ) external returns (uint256 amountCalculatedRaw, uint256 amountInRaw, uint256 amountOutRaw);

    /*******************************************************************************
                                     Miscellaneous
    *******************************************************************************/

    /**
     * @notice Returns the VaultExtension contract address.
     * @dev Function is in the main Vault contract. The VaultExtension handles less critical or frequently used
     * functions, since delegate calls through the Vault are more expensive than direct calls.
     *
     * @return vaultExtension Address of the VaultExtension
     */
    function getVaultExtension() external view returns (address vaultExtension);
}


// File: @balancer-labs/v3-interfaces/contracts/vault/VaultTypes.sol

// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.24;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";

import { IRateProvider } from "../solidity-utils/helpers/IRateProvider.sol";

/**
 * @notice Represents a pool's liquidity management configuration.
 * @param disableUnbalancedLiquidity If set, liquidity can only be added or removed proportionally
 * @param enableAddLiquidityCustom If set, the pool has implemented `onAddLiquidityCustom`
 * @param enableRemoveLiquidityCustom If set, the pool has implemented `onRemoveLiquidityCustom`
 * @param enableDonation If set, the pool will not revert if liquidity is added with AddLiquidityKind.DONATION
 */
struct LiquidityManagement {
    bool disableUnbalancedLiquidity;
    bool enableAddLiquidityCustom;
    bool enableRemoveLiquidityCustom;
    bool enableDonation;
}

// @notice Custom type to store the entire configuration of the pool.
type PoolConfigBits is bytes32;

/**
 * @notice Represents a pool's configuration (hooks configuration are separated in another struct).
 * @param liquidityManagement Flags related to adding/removing liquidity
 * @param staticSwapFeePercentage The pool's native swap fee
 * @param aggregateSwapFeePercentage The total swap fee charged, including protocol and pool creator components
 * @param aggregateYieldFeePercentage The total swap fee charged, including protocol and pool creator components
 * @param tokenDecimalDiffs Compressed storage of the token decimals of each pool token
 * @param pauseWindowEndTime Timestamp after which the pool cannot be paused
 * @param isPoolRegistered If true, the pool has been registered with the Vault
 * @param isPoolInitialized If true, the pool has been initialized with liquidity, and is available for trading
 * @param isPoolPaused If true, the pool has been paused (by governance or the pauseManager)
 * @param isPoolInRecoveryMode If true, the pool has been placed in recovery mode, enabling recovery mode withdrawals
 */
struct PoolConfig {
    LiquidityManagement liquidityManagement;
    uint256 staticSwapFeePercentage;
    uint256 aggregateSwapFeePercentage;
    uint256 aggregateYieldFeePercentage;
    uint40 tokenDecimalDiffs;
    uint32 pauseWindowEndTime;
    bool isPoolRegistered;
    bool isPoolInitialized;
    bool isPoolPaused;
    bool isPoolInRecoveryMode;
}

/**
 * @notice The flag portion of the `HooksConfig`.
 * @dev `enableHookAdjustedAmounts` must be true for all contracts that modify the `amountCalculated`
 * in after hooks. Otherwise, the Vault will ignore any "hookAdjusted" amounts. Setting any "shouldCall"
 * flags to true will cause the Vault to call the corresponding hook during operations.
 */
struct HookFlags {
    bool enableHookAdjustedAmounts;
    bool shouldCallBeforeInitialize;
    bool shouldCallAfterInitialize;
    bool shouldCallComputeDynamicSwapFee;
    bool shouldCallBeforeSwap;
    bool shouldCallAfterSwap;
    bool shouldCallBeforeAddLiquidity;
    bool shouldCallAfterAddLiquidity;
    bool shouldCallBeforeRemoveLiquidity;
    bool shouldCallAfterRemoveLiquidity;
}

/// @notice Represents a hook contract configuration for a pool (HookFlags + hooksContract address).
struct HooksConfig {
    bool enableHookAdjustedAmounts;
    bool shouldCallBeforeInitialize;
    bool shouldCallAfterInitialize;
    bool shouldCallComputeDynamicSwapFee;
    bool shouldCallBeforeSwap;
    bool shouldCallAfterSwap;
    bool shouldCallBeforeAddLiquidity;
    bool shouldCallAfterAddLiquidity;
    bool shouldCallBeforeRemoveLiquidity;
    bool shouldCallAfterRemoveLiquidity;
    address hooksContract;
}

/**
 * @notice Represents temporary state used during a swap operation.
 * @param indexIn The zero-based index of tokenIn
 * @param indexOut The zero-based index of tokenOut
 * @param amountGivenScaled18 The amountGiven (i.e., tokenIn for ExactIn), adjusted for token decimals
 * @param swapFeePercentage The swap fee to be applied (might be static or dynamic)
 */
struct SwapState {
    uint256 indexIn;
    uint256 indexOut;
    uint256 amountGivenScaled18;
    uint256 swapFeePercentage;
}

/**
 * @notice Represents the Vault's configuration.
 * @param isQueryDisabled If set to true, disables query functionality of the Vault. Can be modified by governance
 * @param isVaultPaused If set to true, swaps and add/remove liquidity operations are halted
 * @param areBuffersPaused If set to true, the Vault wrap/unwrap primitives associated with buffers will be disabled
 */
struct VaultState {
    bool isQueryDisabled;
    bool isVaultPaused;
    bool areBuffersPaused;
}

/**
 * @notice Represents the accounts holding certain roles for a given pool. This is passed in on pool registration.
 * @param pauseManager Account empowered to pause/unpause the pool (note that governance can always pause a pool)
 * @param swapFeeManager Account empowered to set static swap fees for a pool (or 0 to delegate to governance)
 * @param poolCreator Account empowered to set the pool creator fee (or 0 if all fees go to the protocol and LPs)
 */
struct PoolRoleAccounts {
    address pauseManager;
    address swapFeeManager;
    address poolCreator;
}

/*******************************************************************************
                                   Tokens
*******************************************************************************/

// Note that the following tokens are unsupported by the Vault. This list is not meant to be exhaustive, but covers
// many common types of tokens that will not work with the Vault architecture. (See https://github.com/d-xo/weird-erc20
// for examples of token features that are problematic for many protocols.)
//
// * Rebasing tokens (e.g., aDAI). The Vault keeps track of token balances in its internal accounting; any token whose
//   balance changes asynchronously (i.e., outside a swap or liquidity operation), would get out-of-sync with this
//   internal accounting. This category would also include "airdrop" tokens, whose balances can change unexpectedly.
//
// * Double entrypoint (e.g., old Synthetix tokens, now fixed). These could likewise bypass internal accounting by
//   registering the token under one address, then accessing it through another. This is especially troublesome
//   in v3, with the introduction of ERC4626 buffers.
//
// * Fee on transfer (e.g., PAXG). The Vault issues credits and debits according to given and calculated token amounts,
//   and settlement assumes that the send/receive transfer functions transfer exactly the given number of tokens.
//   If this is not the case, transactions will not settle. Unlike with the other types, which are fundamentally
//   incompatible, it would be possible to design a Router to handle this - but we didn't try it. In any case, it's
//   not supported in the current Routers.
//
// * Tokens with more than 18 decimals (e.g., YAM-V2). The Vault handles token scaling: i.e., handling I/O for
//   amounts in native token decimals, but doing calculations with full 18-decimal precision. This requires reading
//   and storing the decimals for each token. Since virtually all tokens are 18 or fewer decimals, and we have limited
//   storage space, 18 was a reasonable maximum. Unlike the other types, this is enforceable by the Vault. Attempting
//   to register such tokens will revert with `InvalidTokenDecimals`. Of course, we must also be able to read the token
//   decimals, so the Vault only supports tokens that implement `IERC20Metadata.decimals`, and return a value less than
//   or equal to 18.
//
//  * Token decimals are checked and stored only once, on registration. Valid tokens store their decimals as immutable
//    variables or constants. Malicious tokens that don't respect this basic property would not work anywhere in DeFi.
//
// These types of tokens are supported but discouraged, as they don't tend to play well with AMMs generally.
//
// * Very low-decimal tokens (e.g., GUSD). The Vault has been extensively tested with 6-decimal tokens (e.g., USDC),
//   but going much below that may lead to unanticipated effects due to precision loss, especially with smaller trade
//   values.
//
// * Revert on zero value approval/transfer. The Vault has been tested against these, but peripheral contracts, such
//   as hooks, might not have been designed with this in mind.
//
// * Other types from "weird-erc20," such as upgradeable, pausable, or tokens with blocklists. We have seen cases
//   where a token upgrade fails, "bricking" the token - and many operations on pools containing that token. Any
//   sort of "permissioned" token that can make transfers fail can cause operations on pools containing them to
//   revert. Even Recovery Mode cannot help then, as it does a proportional withdrawal of all tokens. If one of
//   them is bricked, the whole operation will revert. Since v3 does not have "internal balances" like v2, there
//   is no recourse.
//
//   Of course, many tokens in common use have some of these "features" (especially centralized stable coins), so
//   we have to support them anyway. Working with common centralized tokens is a risk common to all of DeFi.

/**
 * @notice Token types supported by the Vault.
 * @dev In general, pools may contain any combination of these tokens.
 *
 * STANDARD tokens (e.g., BAL, WETH) have no rate provider.
 * WITH_RATE tokens (e.g., wstETH) require a rate provider. These may be tokens like wstETH, which need to be wrapped
 * because the underlying stETH token is rebasing, and such tokens are unsupported by the Vault. They may also be
 * tokens like sEUR, which track an underlying asset, but are not yield-bearing. Finally, this encompasses
 * yield-bearing ERC4626 tokens, which can be used to facilitate swaps without requiring wrapping or unwrapping
 * in most cases. The `paysYieldFees` flag can be used to indicate whether a token is yield-bearing (e.g., waDAI),
 * not yield-bearing (e.g., sEUR), or yield-bearing but exempt from fees (e.g., in certain nested pools, where
 * yield fees are charged elsewhere).
 *
 * NB: STANDARD must always be the first enum element, so that newly initialized data structures default to Standard.
 */
enum TokenType {
    STANDARD,
    WITH_RATE
}

/**
 * @notice Encapsulate the data required for the Vault to support a token of the given type.
 * @dev For STANDARD tokens, the rate provider address must be 0, and paysYieldFees must be false. All WITH_RATE tokens
 * need a rate provider, and may or may not be yield-bearing.
 *
 * At registration time, it is useful to include the token address along with the token parameters in the structure
 * passed to `registerPool`, as the alternative would be parallel arrays, which would be error prone and require
 * validation checks. `TokenConfig` is only used for registration, and is never put into storage (see `TokenInfo`).
 *
 * @param token The token address
 * @param tokenType The token type (see the enum for supported types)
 * @param rateProvider The rate provider for a token (see further documentation above)
 * @param paysYieldFees Flag indicating whether yield fees should be charged on this token
 */
struct TokenConfig {
    IERC20 token;
    TokenType tokenType;
    IRateProvider rateProvider;
    bool paysYieldFees;
}

/**
 * @notice This data structure is stored in `_poolTokenInfo`, a nested mapping from pool -> (token -> TokenInfo).
 * @dev Since the token is already the key of the nested mapping, it would be redundant (and an extra SLOAD) to store
 * it again in the struct. When we construct PoolData, the tokens are separated into their own array.
 *
 * @param tokenType The token type (see the enum for supported types)
 * @param rateProvider The rate provider for a token (see further documentation above)
 * @param paysYieldFees Flag indicating whether yield fees should be charged on this token
 */
struct TokenInfo {
    TokenType tokenType;
    IRateProvider rateProvider;
    bool paysYieldFees;
}

/**
 * @notice Data structure used to represent the current pool state in memory
 * @param poolConfigBits Custom type to store the entire configuration of the pool.
 * @param tokens Pool tokens, sorted in token registration order
 * @param tokenInfo Configuration data for each token, sorted in token registration order
 * @param balancesRaw Token balances in native decimals
 * @param balancesLiveScaled18 Token balances after paying yield fees, applying decimal scaling and rates
 * @param tokenRates 18-decimal FP values for rate tokens (e.g., yield-bearing), or FP(1) for standard tokens
 * @param decimalScalingFactors Conversion factor used to adjust for token decimals for uniform precision in
 * calculations. It is 1e18 (FP 1) for 18-decimal tokens
 */
struct PoolData {
    PoolConfigBits poolConfigBits;
    IERC20[] tokens;
    TokenInfo[] tokenInfo;
    uint256[] balancesRaw;
    uint256[] balancesLiveScaled18;
    uint256[] tokenRates;
    uint256[] decimalScalingFactors;
}

enum Rounding {
    ROUND_UP,
    ROUND_DOWN
}

/*******************************************************************************
                                    Swaps
*******************************************************************************/

enum SwapKind {
    EXACT_IN,
    EXACT_OUT
}

// There are two "SwapParams" structs defined below. `VaultSwapParams` corresponds to the external swap API defined
// in the Router contracts, which uses explicit token addresses, the amount given and limit on the calculated amount
// expressed in native token decimals, and optional user data passed in from the caller.
//
// `PoolSwapParams` passes some of this information through (kind, userData), but "translates" the parameters to fit
// the internal swap API used by `IBasePool`. It scales amounts to full 18-decimal precision, adds the token balances,
// converts the raw token addresses to indices, and adds the address of the Router originating the request. It does
// not need the limit, since this is checked at the Router level.

/**
 * @notice Data passed into primary Vault `swap` operations.
 * @param kind Type of swap (Exact In or Exact Out)
 * @param pool The pool with the tokens being swapped
 * @param tokenIn The token entering the Vault (balance increases)
 * @param tokenOut The token leaving the Vault (balance decreases)
 * @param amountGivenRaw Amount specified for tokenIn or tokenOut (depending on the type of swap)
 * @param limitRaw Minimum or maximum value of the calculated amount (depending on the type of swap)
 * @param userData Additional (optional) user data
 */
struct VaultSwapParams {
    SwapKind kind;
    address pool;
    IERC20 tokenIn;
    IERC20 tokenOut;
    uint256 amountGivenRaw;
    uint256 limitRaw;
    bytes userData;
}

/**
 * @notice Data for a swap operation, used by contracts implementing `IBasePool`.
 * @param kind Type of swap (exact in or exact out)
 * @param amountGivenScaled18 Amount given based on kind of the swap (e.g., tokenIn for EXACT_IN)
 * @param balancesScaled18 Current pool balances
 * @param indexIn Index of tokenIn
 * @param indexOut Index of tokenOut
 * @param router The address (usually a router contract) that initiated a swap operation on the Vault
 * @param userData Additional (optional) data required for the swap
 */
struct PoolSwapParams {
    SwapKind kind;
    uint256 amountGivenScaled18;
    uint256[] balancesScaled18;
    uint256 indexIn;
    uint256 indexOut;
    address router;
    bytes userData;
}

/**
 * @notice Data for the hook after a swap operation.
 * @param kind Type of swap (exact in or exact out)
 * @param tokenIn Token to be swapped from
 * @param tokenOut Token to be swapped to
 * @param amountInScaled18 Amount of tokenIn (entering the Vault)
 * @param amountOutScaled18 Amount of tokenOut (leaving the Vault)
 * @param tokenInBalanceScaled18 Updated (after swap) balance of tokenIn
 * @param tokenOutBalanceScaled18 Updated (after swap) balance of tokenOut
 * @param amountCalculatedScaled18 Token amount calculated by the swap
 * @param amountCalculatedRaw Token amount calculated by the swap
 * @param router The address (usually a router contract) that initiated a swap operation on the Vault
 * @param pool Pool address
 * @param userData Additional (optional) data required for the swap
 */
struct AfterSwapParams {
    SwapKind kind;
    IERC20 tokenIn;
    IERC20 tokenOut;
    uint256 amountInScaled18;
    uint256 amountOutScaled18;
    uint256 tokenInBalanceScaled18;
    uint256 tokenOutBalanceScaled18;
    uint256 amountCalculatedScaled18;
    uint256 amountCalculatedRaw;
    address router;
    address pool;
    bytes userData;
}

/*******************************************************************************
                                Add liquidity
*******************************************************************************/

enum AddLiquidityKind {
    PROPORTIONAL,
    UNBALANCED,
    SINGLE_TOKEN_EXACT_OUT,
    DONATION,
    CUSTOM
}

/**
 * @notice Data for an add liquidity operation.
 * @param pool Address of the pool
 * @param to Address of user to mint to
 * @param maxAmountsIn Maximum amounts of input tokens
 * @param minBptAmountOut Minimum amount of output pool tokens
 * @param kind Add liquidity kind
 * @param userData Optional user data
 */
struct AddLiquidityParams {
    address pool;
    address to;
    uint256[] maxAmountsIn;
    uint256 minBptAmountOut;
    AddLiquidityKind kind;
    bytes userData;
}

/*******************************************************************************
                                Remove liquidity
*******************************************************************************/

enum RemoveLiquidityKind {
    PROPORTIONAL,
    SINGLE_TOKEN_EXACT_IN,
    SINGLE_TOKEN_EXACT_OUT,
    CUSTOM
}

/**
 * @notice Data for an remove liquidity operation.
 * @param pool Address of the pool
 * @param from Address of user to burn from
 * @param maxBptAmountIn Maximum amount of input pool tokens
 * @param minAmountsOut Minimum amounts of output tokens
 * @param kind Remove liquidity kind
 * @param userData Optional user data
 */
struct RemoveLiquidityParams {
    address pool;
    address from;
    uint256 maxBptAmountIn;
    uint256[] minAmountsOut;
    RemoveLiquidityKind kind;
    bytes userData;
}

/*******************************************************************************
                                Remove liquidity
*******************************************************************************/

enum WrappingDirection {
    WRAP,
    UNWRAP
}

/**
 * @notice Data for a wrap/unwrap operation.
 * @param kind Type of swap (Exact In or Exact Out)
 * @param direction Direction of the wrapping operation (Wrap or Unwrap)
 * @param wrappedToken Wrapped token, compatible with interface ERC4626
 * @param amountGivenRaw Amount specified for tokenIn or tokenOut (depends on the type of swap and wrapping direction)
 * @param limitRaw Minimum or maximum amount specified for the other token (depends on the type of swap and wrapping
 * direction)
 */
struct BufferWrapOrUnwrapParams {
    SwapKind kind;
    WrappingDirection direction;
    IERC4626 wrappedToken;
    uint256 amountGivenRaw;
    uint256 limitRaw;
}

// Protocol Fees are 24-bit values. We transform them by multiplying by 1e11, so that they can be set to any value
// between 0% and 100% (step 0.00001%). Protocol and pool creator fees are set in the `ProtocolFeeController`, and
// ensure both constituent and aggregate fees do not exceed this precision.
uint256 constant FEE_BITLENGTH = 24;
uint256 constant FEE_SCALING_FACTOR = 1e11;
// Used to ensure the safety of fee-related math (e.g., pools or hooks don't set it greater than 100%).
// This value should work for practical purposes and is well within the max precision requirements.
uint256 constant MAX_FEE_PERCENTAGE = 99.9999e16; // 99.9999%


// File: @balancer-labs/v3-solidity-utils/contracts/helpers/BufferHelpers.sol

// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.24;

import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";

import { PackedTokenBalance } from "./PackedTokenBalance.sol";

library BufferHelpers {
    using PackedTokenBalance for bytes32;
    using SafeCast for *;

    /**
     * @notice Returns the imbalance of a buffer in terms of the underlying asset.
     * @dev The imbalance refers to the difference between the buffer's underlying asset balance and its wrapped asset
     * balance, both expressed in terms of the underlying asset. A positive imbalance means the buffer holds more
     * underlying assets than wrapped assets, indicating that the excess underlying should be wrapped to restore
     * balance. Conversely, a negative imbalance means the buffer has more wrapped assets than underlying assets, so
     * during a wrap operation, fewer underlying tokens need to be wrapped, and the surplus wrapped tokens can be
     * returned to the caller.
     * For instance, consider the following scenario:
     * - buffer balances: 2 wrapped and 10 underlying
     * - wrapped rate: 2
     * - normalized buffer balances: 4 wrapped as underlying (2 wrapped * rate) and 10 underlying
     * - underlying token imbalance = (10 - 4) / 2 = 3 underlying
     * We need to wrap 3 underlying tokens to rebalance the buffer.
     * - 3 underlying = 1.5 wrapped
     * - final balances: 3.5 wrapped (2 existing + 1.5 new) and 7 underlying (10 existing - 3)
     * These balances are equal value, given the rate.
     */
    function getBufferUnderlyingImbalance(bytes32 bufferBalance, IERC4626 wrappedToken) internal view returns (int256) {
        int256 underlyingBalance = bufferBalance.getBalanceRaw().toInt256();

        int256 wrappedBalanceAsUnderlying = 0;
        if (bufferBalance.getBalanceDerived() > 0) {
            // The buffer underlying imbalance is used when wrapping (it means, deposit underlying and get wrapped
            // tokens), so we use `previewMint` to convert wrapped balance to underlying. The `mint` function is used
            // here, as it performs the inverse of a `deposit` operation.
            wrappedBalanceAsUnderlying = wrappedToken.previewMint(bufferBalance.getBalanceDerived()).toInt256();
        }

        // The return value may be positive (excess of underlying) or negative (excess of wrapped).
        return (underlyingBalance - wrappedBalanceAsUnderlying) / 2;
    }

    /**
     * @notice Returns the imbalance of a buffer in terms of the wrapped asset.
     * @dev The imbalance refers to the difference between the buffer's underlying asset balance and its wrapped asset
     * balance, both expressed in terms of the wrapped asset. A positive imbalance means the buffer holds more
     * wrapped assets than underlying assets, indicating that the excess wrapped should be unwrapped to restore
     * balance. Conversely, a negative imbalance means the buffer has more underlying assets than wrapped assets, so
     * during an unwrap operation, fewer wrapped tokens need to be unwrapped, and the surplus underlying tokens can be
     * returned to the caller.
     * For instance, consider the following scenario:
     * - buffer balances: 10 wrapped and 4 underlying
     * - wrapped rate: 2
     * - normalized buffer balances: 10 wrapped and 2 underlying as wrapped (2 underlying / rate)
     * - imbalance of wrapped = (10 - 2) / 2 = 4 wrapped
     * We need to unwrap 4 wrapped tokens to rebalance the buffer.
     * - 4 wrapped = 8 underlying
     * - final balances: 6 wrapped (10 existing - 4) and 12 underlying (4 existing + 8 new)
     * These balances are equal value, given the rate.
     */
    function getBufferWrappedImbalance(bytes32 bufferBalance, IERC4626 wrappedToken) internal view returns (int256) {
        int256 wrappedBalance = bufferBalance.getBalanceDerived().toInt256();

        int256 underlyingBalanceAsWrapped = 0;
        if (bufferBalance.getBalanceRaw() > 0) {
            // The buffer wrapped imbalance is used when unwrapping (it means, deposit wrapped and get underlying
            // tokens), so we use `previewWithdraw` to convert underlying balance to wrapped. The `withdraw` function
            // is used here, as it performs the inverse of a `redeem` operation.
            underlyingBalanceAsWrapped = wrappedToken.previewWithdraw(bufferBalance.getBalanceRaw()).toInt256();
        }

        // The return value may be positive (excess of wrapped) or negative (excess of underlying).
        return (wrappedBalance - underlyingBalanceAsWrapped) / 2;
    }
}


// File: @balancer-labs/v3-solidity-utils/contracts/helpers/CastingHelpers.sol

// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.24;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @notice Library of helper functions related to typecasting arrays.
library CastingHelpers {
    /// @dev Returns a native array of addresses as an IERC20[] array.
    function asIERC20(address[] memory addresses) internal pure returns (IERC20[] memory tokens) {
        // solhint-disable-next-line no-inline-assembly
        assembly ("memory-safe") {
            tokens := addresses
        }
    }

    /// @dev Returns an IERC20[] array as an address[] array.
    function asAddress(IERC20[] memory tokens) internal pure returns (address[] memory addresses) {
        // solhint-disable-next-line no-inline-assembly
        assembly ("memory-safe") {
            addresses := tokens
        }
    }
}


// File: @balancer-labs/v3-solidity-utils/contracts/helpers/EVMCallModeHelpers.sol

// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.24;

/// @notice Library used to check whether the current operation was initiated through a static call.
library EVMCallModeHelpers {
    /// @notice A state-changing transaction was initiated in a context that only allows static calls.
    error NotStaticCall();

    /**
     * @dev Detects whether the current transaction is a static call.
     * A static call is one where `tx.origin` equals 0x0 for most implementations.
     * See this tweet for a table on how transaction parameters are set on different platforms:
     * https://twitter.com/0xkarmacoma/status/1493380279309717505
     *
     * Solidity eth_call reference docs are here: https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_call
     */
    function isStaticCall() internal view returns (bool) {
        return tx.origin == address(0);
        // solhint-disable-previous-line avoid-tx-origin
    }
}


// File: @balancer-labs/v3-solidity-utils/contracts/helpers/InputHelpers.sol

// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.24;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { CastingHelpers } from "./CastingHelpers.sol";

library InputHelpers {
    /// @notice Arrays passed to a function and intended to be parallel have different lengths.
    error InputLengthMismatch();

    /**
     * @notice More than one non-zero value was given for a single token operation.
     * @dev Input arrays for single token add/remove liquidity operations are expected to have only one non-zero value,
     * corresponding to the token being added or removed. This error results if there are multiple non-zero entries.
     */
    error MultipleNonZeroInputs();

    /**
     * @notice No valid input was given for a single token operation.
     * @dev Input arrays for single token add/remove liquidity operations are expected to have one non-zero value,
     * corresponding to the token being added or removed. This error results if all entries are zero.
     */
    error AllZeroInputs();

    /**
     * @notice The tokens supplied to an array argument were not sorted in numerical order.
     * @dev Tokens are not sorted by address on registration. This is an optimization so that off-chain processes can
     * predict the token order without having to query the Vault. (It is also legacy v2 behavior.)
     */
    error TokensNotSorted();

    function ensureInputLengthMatch(uint256 a, uint256 b) internal pure {
        if (a != b) {
            revert InputLengthMismatch();
        }
    }

    function ensureInputLengthMatch(uint256 a, uint256 b, uint256 c) internal pure {
        if (a != b || b != c) {
            revert InputLengthMismatch();
        }
    }

    // Find the single non-zero input; revert if there is not exactly one such value.
    function getSingleInputIndex(uint256[] memory maxAmountsIn) internal pure returns (uint256 inputIndex) {
        uint256 length = maxAmountsIn.length;
        inputIndex = length;

        for (uint256 i = 0; i < length; ++i) {
            if (maxAmountsIn[i] != 0) {
                if (inputIndex != length) {
                    revert MultipleNonZeroInputs();
                }
                inputIndex = i;
            }
        }

        if (inputIndex >= length) {
            revert AllZeroInputs();
        }

        return inputIndex;
    }

    /**
     * @dev Sort an array of tokens, mutating in place (and also returning them).
     * This assumes the tokens have been (or will be) validated elsewhere for length
     * and non-duplication. All this does is the sorting.
     *
     * A bubble sort should be gas- and bytecode-efficient enough for such small arrays.
     * Could have also done "manual" comparisons for each of the cases, but this is
     * about the same number of operations, and more concise.
     *
     * This is less efficient for larger token count (i.e., above 4), but such pools should
     * be rare. And in any case, sorting is only done on-chain in test code.
     */
    function sortTokens(IERC20[] memory tokens) internal pure returns (IERC20[] memory) {
        for (uint256 i = 0; i < tokens.length - 1; ++i) {
            for (uint256 j = 0; j < tokens.length - i - 1; ++j) {
                if (tokens[j] > tokens[j + 1]) {
                    // Swap if they're out of order.
                    (tokens[j], tokens[j + 1]) = (tokens[j + 1], tokens[j]);
                }
            }
        }

        return tokens;
    }

    /// @dev Ensure an array of tokens is sorted. As above, does not validate length or uniqueness.
    function ensureSortedTokens(IERC20[] memory tokens) internal pure {
        IERC20 previous = tokens[0];

        for (uint256 i = 1; i < tokens.length; ++i) {
            IERC20 current = tokens[i];

            if (previous > current) {
                revert TokensNotSorted();
            }

            previous = current;
        }
    }
}


// File: @balancer-labs/v3-solidity-utils/contracts/helpers/PackedTokenBalance.sol

// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.24;

/**
 * @notice This library represents a data structure for packing a token's current raw and derived balances. A derived
 * balance can be the "last" live balance scaled18 of the raw token, or the balance of the wrapped version of the
 * token in a vault buffer, among others.
 *
 * @dev We could use a Solidity struct to pack balance values together in a single storage slot, but unfortunately
 * Solidity only allows for structs to live in either storage, calldata or memory. Because a memory struct still takes
 * up a slot in the stack (to store its memory location), and because the entire balance fits in a single stack slot
 * (two 128 bit values), using memory is strictly less gas performant. Therefore, we do manual packing and unpacking.
 *
 * We could also use custom types now, but given the simplicity here, and the existing EnumerableMap type, it seemed
 * easier to leave it as a bytes32.
 */
library PackedTokenBalance {
    // The 'rawBalance' portion of the balance is stored in the least significant 128 bits of a 256 bit word, while the
    // The 'derivedBalance' part uses the remaining 128 bits.
    uint256 private constant _MAX_BALANCE = 2 ** (128) - 1;

    /// @notice One of the balances is above the maximum value that can be stored.
    error BalanceOverflow();

    function getBalanceRaw(bytes32 balance) internal pure returns (uint256) {
        return uint256(balance) & _MAX_BALANCE;
    }

    function getBalanceDerived(bytes32 balance) internal pure returns (uint256) {
        return uint256(balance >> 128) & _MAX_BALANCE;
    }

    /// @dev Sets only the raw balance of balances and returns the new bytes32 balance.
    function setBalanceRaw(bytes32 balance, uint256 newBalanceRaw) internal pure returns (bytes32) {
        return toPackedBalance(newBalanceRaw, getBalanceDerived(balance));
    }

    /// @dev Sets only the derived balance of balances and returns the new bytes32 balance.
    function setBalanceDerived(bytes32 balance, uint256 newBalanceDerived) internal pure returns (bytes32) {
        return toPackedBalance(getBalanceRaw(balance), newBalanceDerived);
    }

    /// @dev Validates the size of `balanceRaw` and `balanceDerived`, then returns a packed balance bytes32.
    function toPackedBalance(uint256 balanceRaw, uint256 balanceDerived) internal pure returns (bytes32) {
        if (balanceRaw > _MAX_BALANCE || balanceDerived > _MAX_BALANCE) {
            revert BalanceOverflow();
        }

        return _pack(balanceRaw, balanceDerived);
    }

    /// @dev Decode and fetch both balances.
    function fromPackedBalance(bytes32 balance) internal pure returns (uint256 balanceRaw, uint256 balanceDerived) {
        return (getBalanceRaw(balance), getBalanceDerived(balance));
    }

    /// @dev Packs two uint128 values into a packed balance bytes32. It does not check balance sizes.
    function _pack(uint256 leastSignificant, uint256 mostSignificant) private pure returns (bytes32) {
        return bytes32((mostSignificant << 128) + leastSignificant);
    }
}


// File: @balancer-labs/v3-solidity-utils/contracts/helpers/ScalingHelpers.sol

// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.24;

import { FixedPoint } from "../math/FixedPoint.sol";
import { InputHelpers } from "./InputHelpers.sol";

/**
 * @notice Helper functions to apply/undo token decimal and rate adjustments, rounding in the direction indicated.
 * @dev To simplify Pool logic, all token balances and amounts are normalized to behave as if the token had
 * 18 decimals. When comparing DAI (18 decimals) and USDC (6 decimals), 1 USDC and 1 DAI would both be
 * represented as 1e18. This allows us to not consider differences in token decimals in the internal Pool
 * math, simplifying it greatly.
 *
 * The Vault does not support tokens with more than 18 decimals (see `_MAX_TOKEN_DECIMALS` in `VaultStorage`),
 * or tokens that do not implement `IERC20Metadata.decimals`.
 *
 * These helpers can also be used to scale amounts by other 18-decimal floating point values, such as rates.
 */
library ScalingHelpers {
    using FixedPoint for *;
    using ScalingHelpers for uint256;

    /***************************************************************************
                                Single Value Functions
    ***************************************************************************/

    /**
     * @notice Applies `scalingFactor` and `tokenRate` to `amount`.
     * @dev This may result in a larger or equal value, depending on whether it needed scaling/rate adjustment or not.
     * The result is rounded down.
     *
     * @param amount Amount to be scaled up to 18 decimals
     * @param scalingFactor The token decimal scaling factor, `10^(18-tokenDecimals)`
     * @param tokenRate The token rate scaling factor
     * @return result The final 18-decimal precision result, rounded down
     */
    function toScaled18ApplyRateRoundDown(
        uint256 amount,
        uint256 scalingFactor,
        uint256 tokenRate
    ) internal pure returns (uint256) {
        return (amount * scalingFactor).mulDown(tokenRate);
    }

    /**
     * @notice Applies `scalingFactor` and `tokenRate` to `amount`.
     * @dev This may result in a larger or equal value, depending on whether it needed scaling/rate adjustment or not.
     * The result is rounded up.
     *
     * @param amount Amount to be scaled up to 18 decimals
     * @param scalingFactor The token decimal scaling factor, `10^(18-tokenDecimals)`
     * @param tokenRate The token rate scaling factor
     * @return result The final 18-decimal precision result, rounded up
     */
    function toScaled18ApplyRateRoundUp(
        uint256 amount,
        uint256 scalingFactor,
        uint256 tokenRate
    ) internal pure returns (uint256) {
        return (amount * scalingFactor).mulUp(tokenRate);
    }

    /**
     * @notice Reverses the `scalingFactor` and `tokenRate` applied to `amount`.
     * @dev This may result in a smaller or equal value, depending on whether it needed scaling/rate adjustment or not.
     * The result is rounded down.
     *
     * @param amount Amount to be scaled down to native token decimals
     * @param scalingFactor The token decimal scaling factor, `10^(18-tokenDecimals)`
     * @param tokenRate The token rate scaling factor
     * @return result The final native decimal result, rounded down
     */
    function toRawUndoRateRoundDown(
        uint256 amount,
        uint256 scalingFactor,
        uint256 tokenRate
    ) internal pure returns (uint256) {
        // Do division last. Scaling factor is not a FP18, but a FP18 normalized by FP(1).
        // `scalingFactor * tokenRate` is a precise FP18, so there is no rounding direction here.
        return FixedPoint.divDown(amount, scalingFactor * tokenRate);
    }

    /**
     * @notice Reverses the `scalingFactor` and `tokenRate` applied to `amount`.
     * @dev This may result in a smaller or equal value, depending on whether it needed scaling/rate adjustment or not.
     * The result is rounded up.
     *
     * @param amount Amount to be scaled down to native token decimals
     * @param scalingFactor The token decimal scaling factor, `10^(18-tokenDecimals)`
     * @param tokenRate The token rate scaling factor
     * @return result The final native decimal result, rounded up
     */
    function toRawUndoRateRoundUp(
        uint256 amount,
        uint256 scalingFactor,
        uint256 tokenRate
    ) internal pure returns (uint256) {
        // Do division last. Scaling factor is not a FP18, but a FP18 normalized by FP(1).
        // `scalingFactor * tokenRate` is a precise FP18, so there is no rounding direction here.
        return FixedPoint.divUp(amount, scalingFactor * tokenRate);
    }

    /***************************************************************************
                                    Array Functions
    ***************************************************************************/

    function copyToArray(uint256[] memory from, uint256[] memory to) internal pure {
        uint256 length = from.length;
        InputHelpers.ensureInputLengthMatch(length, to.length);

        // solhint-disable-next-line no-inline-assembly
        assembly ("memory-safe") {
            mcopy(add(to, 0x20), add(from, 0x20), mul(length, 0x20))
        }
    }

    /**
     * @notice Same as `toScaled18ApplyRateRoundDown`, but for an entire array.
     * @dev This function does not return anything, but instead *mutates* the `amounts` array.
     * @param amounts Amounts to be scaled up to 18 decimals, sorted in token registration order
     * @param scalingFactors The token decimal scaling factors, sorted in token registration order
     * @param tokenRates The token rate scaling factors, sorted in token registration order
     */
    function toScaled18ApplyRateRoundDownArray(
        uint256[] memory amounts,
        uint256[] memory scalingFactors,
        uint256[] memory tokenRates
    ) internal pure {
        uint256 length = amounts.length;
        InputHelpers.ensureInputLengthMatch(length, scalingFactors.length, tokenRates.length);

        for (uint256 i = 0; i < length; ++i) {
            amounts[i] = amounts[i].toScaled18ApplyRateRoundDown(scalingFactors[i], tokenRates[i]);
        }
    }

    /**
     * @notice Same as `toScaled18ApplyRateRoundDown`, but returns a new array, leaving the original intact.
     * @param amounts Amounts to be scaled up to 18 decimals, sorted in token registration order
     * @param scalingFactors The token decimal scaling factors, sorted in token registration order
     * @param tokenRates The token rate scaling factors, sorted in token registration order
     * @return results The final 18 decimal results, sorted in token registration order, rounded down
     */
    function copyToScaled18ApplyRateRoundDownArray(
        uint256[] memory amounts,
        uint256[] memory scalingFactors,
        uint256[] memory tokenRates
    ) internal pure returns (uint256[] memory) {
        uint256 length = amounts.length;
        InputHelpers.ensureInputLengthMatch(length, scalingFactors.length, tokenRates.length);
        uint256[] memory amountsScaled18 = new uint256[](length);

        for (uint256 i = 0; i < length; ++i) {
            amountsScaled18[i] = amounts[i].toScaled18ApplyRateRoundDown(scalingFactors[i], tokenRates[i]);
        }

        return amountsScaled18;
    }

    /**
     * @notice Same as `toScaled18ApplyRateRoundUp`, but for an entire array.
     * @dev This function does not return anything, but instead *mutates* the `amounts` array.
     * @param amounts Amounts to be scaled up to 18 decimals, sorted in token registration order
     * @param scalingFactors The token decimal scaling factors, sorted in token registration order
     * @param tokenRates The token rate scaling factors, sorted in token registration order
     */
    function toScaled18ApplyRateRoundUpArray(
        uint256[] memory amounts,
        uint256[] memory scalingFactors,
        uint256[] memory tokenRates
    ) internal pure {
        uint256 length = amounts.length;
        InputHelpers.ensureInputLengthMatch(length, scalingFactors.length, tokenRates.length);

        for (uint256 i = 0; i < length; ++i) {
            amounts[i] = amounts[i].toScaled18ApplyRateRoundUp(scalingFactors[i], tokenRates[i]);
        }
    }

    /**
     * @notice Same as `toScaled18ApplyRateRoundUp`, but returns a new array, leaving the original intact.
     * @param amounts Amounts to be scaled up to 18 decimals, sorted in token registration order
     * @param scalingFactors The token decimal scaling factors, sorted in token registration order
     * @param tokenRates The token rate scaling factors, sorted in token registration order
     * @return results The final 18 decimal results, sorted in token registration order, rounded up
     */
    function copyToScaled18ApplyRateRoundUpArray(
        uint256[] memory amounts,
        uint256[] memory scalingFactors,
        uint256[] memory tokenRates
    ) internal pure returns (uint256[] memory) {
        uint256 length = amounts.length;
        InputHelpers.ensureInputLengthMatch(length, scalingFactors.length, tokenRates.length);
        uint256[] memory amountsScaled18 = new uint256[](length);

        for (uint256 i = 0; i < length; ++i) {
            amountsScaled18[i] = amounts[i].toScaled18ApplyRateRoundUp(scalingFactors[i], tokenRates[i]);
        }

        return amountsScaled18;
    }

    /**
     * @notice Rounds up a rate informed by a rate provider.
     * @dev Rates calculated by an external rate provider have rounding errors. Intuitively, a rate provider
     * rounds the rate down so the pool math is executed with conservative amounts. However, when upscaling or
     * downscaling the amount out, the rate should be rounded up to make sure the amounts scaled are conservative.
     * @param rate The original rate
     * @return roundedRate The final rate, with rounding applied
     */
    function computeRateRoundUp(uint256 rate) internal pure returns (uint256) {
        uint256 roundedRate;
        // If rate is divisible by FixedPoint.ONE, roundedRate and rate will be equal. It means that rate has 18 zeros,
        // so there's no rounding issue and the rate should not be rounded up.
        unchecked {
            roundedRate = (rate / FixedPoint.ONE) * FixedPoint.ONE;
        }
        return roundedRate == rate ? rate : rate + 1;
    }
}


// File: @balancer-labs/v3-solidity-utils/contracts/helpers/TransientStorageHelpers.sol

// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.24;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { StorageSlotExtension } from "../openzeppelin/StorageSlotExtension.sol";
import { SlotDerivation } from "../openzeppelin/SlotDerivation.sol";

type TokenDeltaMappingSlotType is bytes32;
type AddressToUintMappingSlot is bytes32;
type UintToAddressToBooleanMappingSlot is bytes32;
type AddressArraySlotType is bytes32;

/**
 * @notice Helper functions to read and write values from transient storage, including support for arrays and mappings.
 * @dev This is temporary, based on Open Zeppelin's partially released library. When the final version is published, we
 * should be able to remove our copies and import directly from OZ. When Solidity catches up and puts direct support
 * for transient storage in the language, we should be able to get rid of this altogether.
 *
 * This only works on networks where EIP-1153 is supported.
 */
library TransientStorageHelpers {
    using SlotDerivation for *;
    using StorageSlotExtension for *;

    /// @notice An index is out of bounds on an array operation (e.g., at).
    error TransientIndexOutOfBounds();

    // Calculate the slot for a transient storage variable.
    function calculateSlot(string memory domain, string memory varName) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(uint256(keccak256(abi.encodePacked("balancer-labs.v3.storage.", domain, ".", varName))) - 1)
            ) & ~bytes32(uint256(0xff));
    }

    /***************************************************************************
                                    Mappings
    ***************************************************************************/

    function tGet(TokenDeltaMappingSlotType slot, IERC20 k1) internal view returns (int256) {
        return TokenDeltaMappingSlotType.unwrap(slot).deriveMapping(address(k1)).asInt256().tload();
    }

    function tSet(TokenDeltaMappingSlotType slot, IERC20 k1, int256 value) internal {
        TokenDeltaMappingSlotType.unwrap(slot).deriveMapping(address(k1)).asInt256().tstore(value);
    }

    function tGet(AddressToUintMappingSlot slot, address key) internal view returns (uint256) {
        return AddressToUintMappingSlot.unwrap(slot).deriveMapping(key).asUint256().tload();
    }

    function tSet(AddressToUintMappingSlot slot, address key, uint256 value) internal {
        AddressToUintMappingSlot.unwrap(slot).deriveMapping(key).asUint256().tstore(value);
    }

    function tGet(
        UintToAddressToBooleanMappingSlot slot,
        uint256 uintKey,
        address addressKey
    ) internal view returns (bool) {
        return
            UintToAddressToBooleanMappingSlot
                .unwrap(slot)
                .deriveMapping(uintKey)
                .deriveMapping(addressKey)
                .asBoolean()
                .tload();
    }

    function tSet(UintToAddressToBooleanMappingSlot slot, uint256 uintKey, address addressKey, bool value) internal {
        UintToAddressToBooleanMappingSlot
            .unwrap(slot)
            .deriveMapping(uintKey)
            .deriveMapping(addressKey)
            .asBoolean()
            .tstore(value);
    }

    // Implement the common "+=" operation: map[key] += value.
    function tAdd(AddressToUintMappingSlot slot, address key, uint256 value) internal {
        AddressToUintMappingSlot.unwrap(slot).deriveMapping(key).asUint256().tstore(tGet(slot, key) + value);
    }

    function tSub(AddressToUintMappingSlot slot, address key, uint256 value) internal {
        AddressToUintMappingSlot.unwrap(slot).deriveMapping(key).asUint256().tstore(tGet(slot, key) - value);
    }

    /***************************************************************************
                                      Arrays
    ***************************************************************************/

    function tLength(AddressArraySlotType slot) internal view returns (uint256) {
        return AddressArraySlotType.unwrap(slot).asUint256().tload();
    }

    function tAt(AddressArraySlotType slot, uint256 index) internal view returns (address) {
        _ensureIndexWithinBounds(slot, index);
        return AddressArraySlotType.unwrap(slot).deriveArray().offset(index).asAddress().tload();
    }

    function tSet(AddressArraySlotType slot, uint256 index, address value) internal {
        _ensureIndexWithinBounds(slot, index);
        AddressArraySlotType.unwrap(slot).deriveArray().offset(index).asAddress().tstore(value);
    }

    function _ensureIndexWithinBounds(AddressArraySlotType slot, uint256 index) private view {
        uint256 length = AddressArraySlotType.unwrap(slot).asUint256().tload();
        if (index >= length) {
            revert TransientIndexOutOfBounds();
        }
    }

    function tUncheckedAt(AddressArraySlotType slot, uint256 index) internal view returns (address) {
        return AddressArraySlotType.unwrap(slot).deriveArray().offset(index).asAddress().tload();
    }

    function tUncheckedSet(AddressArraySlotType slot, uint256 index, address value) internal {
        AddressArraySlotType.unwrap(slot).deriveArray().offset(index).asAddress().tstore(value);
    }

    function tPush(AddressArraySlotType slot, address value) internal {
        // Store the value at offset corresponding to the current length.
        uint256 length = AddressArraySlotType.unwrap(slot).asUint256().tload();
        AddressArraySlotType.unwrap(slot).deriveArray().offset(length).asAddress().tstore(value);
        // Update current length to consider the new value.
        AddressArraySlotType.unwrap(slot).asUint256().tstore(length + 1);
    }

    function tPop(AddressArraySlotType slot) internal returns (address value) {
        uint256 lastElementIndex = AddressArraySlotType.unwrap(slot).asUint256().tload() - 1;
        // Update length to last element. When the index is 0, the slot that holds the length is cleared out.
        AddressArraySlotType.unwrap(slot).asUint256().tstore(lastElementIndex);
        StorageSlotExtension.AddressSlotType lastElementSlot = AddressArraySlotType
            .unwrap(slot)
            .deriveArray()
            .offset(lastElementIndex)
            .asAddress();
        // Return last element.
        value = lastElementSlot.tload();
        // Clear value in temporary storage.
        lastElementSlot.tstore(address(0));
    }

    /***************************************************************************
                                  Uint256 Values
    ***************************************************************************/

    function tIncrement(StorageSlotExtension.Uint256SlotType slot) internal {
        slot.tstore(slot.tload() + 1);
    }

    function tDecrement(StorageSlotExtension.Uint256SlotType slot) internal {
        slot.tstore(slot.tload() - 1);
    }
}


// File: @balancer-labs/v3-solidity-utils/contracts/helpers/WordCodec.sol

// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.24;

import { SignedMath } from "@openzeppelin/contracts/utils/math/SignedMath.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @notice Library for encoding and decoding values stored inside a 256 bit word.
 * @dev Typically used to pack multiple values in a single slot, saving gas by performing fewer storage accesses.
 *
 * Each value is defined by its size and the least significant bit in the word, also known as offset. For example, two
 * 128 bit values may be encoded in a word by assigning one an offset of 0, and the other an offset of 128.
 *
 * We could use Solidity structs to pack values together in a single storage slot instead of relying on a custom and
 * error-prone library, but unfortunately Solidity only allows for structs to live in either storage, calldata or
 * memory. Because a memory struct uses not just memory but also a slot in the stack (to store its memory location),
 * using memory for word-sized values (i.e. of 256 bits or less) is strictly less gas performant, and doesn't even
 * prevent stack-too-deep issues. This is compounded by the fact that Balancer contracts typically are memory-
 * intensive, and the cost of accessing memory increases quadratically with the number of allocated words. Manual
 * packing and unpacking is therefore the preferred approach.
 */
library WordCodec {
    using Math for uint256;
    using SignedMath for int256;

    // solhint-disable no-inline-assembly

    /// @notice Function called with an invalid value.
    error CodecOverflow();

    /// @notice Function called with an invalid bitLength or offset.
    error OutOfBounds();

    /***************************************************************************
                                 In-place Insertion
    ***************************************************************************/

    /**
     * @dev Inserts an unsigned integer of bitLength, shifted by an offset, into a 256 bit word,
     * replacing the old value. Returns the new word.
     */
    function insertUint(
        bytes32 word,
        uint256 value,
        uint256 offset,
        uint256 bitLength
    ) internal pure returns (bytes32 result) {
        _validateEncodingParams(value, offset, bitLength);
        // Equivalent to:
        // uint256 mask = (1 << bitLength) - 1;
        // bytes32 clearedWord = bytes32(uint256(word) & ~(mask << offset));
        // result = clearedWord | bytes32(value << offset);

        assembly ("memory-safe") {
            let mask := sub(shl(bitLength, 1), 1)
            let clearedWord := and(word, not(shl(offset, mask)))
            result := or(clearedWord, shl(offset, value))
        }
    }

    /**
     * @dev Inserts an address (160 bits), shifted by an offset, into a 256 bit word,
     * replacing the old value. Returns the new word.
     */
    function insertAddress(bytes32 word, address value, uint256 offset) internal pure returns (bytes32 result) {
        uint256 addressBitLength = 160;
        _validateEncodingParams(uint256(uint160(value)), offset, addressBitLength);
        // Equivalent to:
        // uint256 mask = (1 << bitLength) - 1;
        // bytes32 clearedWord = bytes32(uint256(word) & ~(mask << offset));
        // result = clearedWord | bytes32(value << offset);

        assembly ("memory-safe") {
            let mask := sub(shl(addressBitLength, 1), 1)
            let clearedWord := and(word, not(shl(offset, mask)))
            result := or(clearedWord, shl(offset, value))
        }
    }

    /**
     * @dev Inserts a signed integer shifted by an offset into a 256 bit word, replacing the old value. Returns
     * the new word.
     *
     * Assumes `value` can be represented using `bitLength` bits.
     */
    function insertInt(bytes32 word, int256 value, uint256 offset, uint256 bitLength) internal pure returns (bytes32) {
        _validateEncodingParams(value, offset, bitLength);

        uint256 mask = (1 << bitLength) - 1;
        bytes32 clearedWord = bytes32(uint256(word) & ~(mask << offset));
        // Integer values need masking to remove the upper bits of negative values.
        return clearedWord | bytes32((uint256(value) & mask) << offset);
    }

    /***************************************************************************
                                      Encoding
    ***************************************************************************/

    /**
     * @dev Encodes an unsigned integer shifted by an offset. Ensures value fits within
     * `bitLength` bits.
     *
     * The return value can be ORed bitwise with other encoded values to form a 256 bit word.
     */
    function encodeUint(uint256 value, uint256 offset, uint256 bitLength) internal pure returns (bytes32) {
        _validateEncodingParams(value, offset, bitLength);

        return bytes32(value << offset);
    }

    /**
     * @dev Encodes a signed integer shifted by an offset.
     *
     * The return value can be ORed bitwise with other encoded values to form a 256 bit word.
     */
    function encodeInt(int256 value, uint256 offset, uint256 bitLength) internal pure returns (bytes32) {
        _validateEncodingParams(value, offset, bitLength);

        uint256 mask = (1 << bitLength) - 1;
        // Integer values need masking to remove the upper bits of negative values.
        return bytes32((uint256(value) & mask) << offset);
    }

    /***************************************************************************
                                      Decoding
    ***************************************************************************/

    /// @dev Decodes and returns an unsigned integer with `bitLength` bits, shifted by an offset, from a 256 bit word.
    function decodeUint(bytes32 word, uint256 offset, uint256 bitLength) internal pure returns (uint256 result) {
        // Equivalent to:
        // result = uint256(word >> offset) & ((1 << bitLength) - 1);

        assembly ("memory-safe") {
            result := and(shr(offset, word), sub(shl(bitLength, 1), 1))
        }
    }

    /// @dev Decodes and returns a signed integer with `bitLength` bits, shifted by an offset, from a 256 bit word.
    function decodeInt(bytes32 word, uint256 offset, uint256 bitLength) internal pure returns (int256 result) {
        int256 maxInt = int256((1 << (bitLength - 1)) - 1);
        uint256 mask = (1 << bitLength) - 1;

        int256 value = int256(uint256(word >> offset) & mask);
        // In case the decoded value is greater than the max positive integer that can be represented with bitLength
        // bits, we know it was originally a negative integer. Therefore, we mask it to restore the sign in the 256 bit
        // representation.
        //
        // Equivalent to:
        // result = value > maxInt ? (value | int256(~mask)) : value;

        assembly ("memory-safe") {
            result := or(mul(gt(value, maxInt), not(mask)), value)
        }
    }

    /// @dev Decodes and returns an address (160 bits), shifted by an offset, from a 256 bit word.
    function decodeAddress(bytes32 word, uint256 offset) internal pure returns (address result) {
        // Equivalent to:
        // result = address(word >> offset) & ((1 << bitLength) - 1);

        assembly ("memory-safe") {
            result := and(shr(offset, word), sub(shl(160, 1), 1))
        }
    }

    /***************************************************************************
                                    Special Cases
    ***************************************************************************/

    /// @dev Decodes and returns a boolean shifted by an offset from a 256 bit word.
    function decodeBool(bytes32 word, uint256 offset) internal pure returns (bool result) {
        // Equivalent to:
        // result = (uint256(word >> offset) & 1) == 1;

        assembly ("memory-safe") {
            result := and(shr(offset, word), 1)
        }
    }

    /**
     * @dev Inserts a boolean value shifted by an offset into a 256 bit word, replacing the old value.
     * Returns the new word.
     */
    function insertBool(bytes32 word, bool value, uint256 offset) internal pure returns (bytes32 result) {
        // Equivalent to:
        // bytes32 clearedWord = bytes32(uint256(word) & ~(1 << offset));
        // bytes32 referenceInsertBool = clearedWord | bytes32(uint256(value ? 1 : 0) << offset);

        assembly ("memory-safe") {
            let clearedWord := and(word, not(shl(offset, 1)))
            result := or(clearedWord, shl(offset, value))
        }
    }

    /***************************************************************************
                                     Helpers
    ***************************************************************************/

    function _validateEncodingParams(uint256 value, uint256 offset, uint256 bitLength) private pure {
        if (offset >= 256) {
            revert OutOfBounds();
        }
        // We never accept 256 bit values (which would make the codec pointless), and the larger the offset the smaller
        // the maximum bit length.
        if (!(bitLength >= 1 && bitLength <= Math.min(255, 256 - offset))) {
            revert OutOfBounds();
        }

        // Testing unsigned values for size is straightforward: their upper bits must be cleared.
        if (value >> bitLength != 0) {
            revert CodecOverflow();
        }
    }

    function _validateEncodingParams(int256 value, uint256 offset, uint256 bitLength) private pure {
        if (offset >= 256) {
            revert OutOfBounds();
        }
        // We never accept 256 bit values (which would make the codec pointless), and the larger the offset the smaller
        // the maximum bit length.
        if (!(bitLength >= 1 && bitLength <= Math.min(255, 256 - offset))) {
            revert OutOfBounds();
        }

        // Testing signed values for size is a bit more involved.
        if (value >= 0) {
            // For positive values, we can simply check that the upper bits are clear. Notice we remove one bit from the
            // length for the sign bit.
            if (value >> (bitLength - 1) != 0) {
                revert CodecOverflow();
            }
        } else {
            // Negative values can receive the same treatment by making them positive, with the caveat that the range
            // for negative values in two's complement supports one more value than for the positive case.
            if ((value + 1).abs() >> (bitLength - 1) != 0) {
                revert CodecOverflow();
            }
        }
    }
}


// File: @balancer-labs/v3-solidity-utils/contracts/math/FixedPoint.sol

// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.24;

import { LogExpMath } from "./LogExpMath.sol";

/// @notice Support 18-decimal fixed point arithmetic. All Vault calculations use this for high and uniform precision.
library FixedPoint {
    /// @notice Attempted division by zero.
    error ZeroDivision();

    // solhint-disable no-inline-assembly
    // solhint-disable private-vars-leading-underscore

    uint256 internal constant ONE = 1e18; // 18 decimal places
    uint256 internal constant TWO = 2 * ONE;
    uint256 internal constant FOUR = 4 * ONE;
    uint256 internal constant MAX_POW_RELATIVE_ERROR = 10000; // 10^(-14)

    function mulDown(uint256 a, uint256 b) internal pure returns (uint256) {
        // Multiplication overflow protection is provided by Solidity 0.8.x.
        uint256 product = a * b;

        return product / ONE;
    }

    function mulUp(uint256 a, uint256 b) internal pure returns (uint256 result) {
        // Multiplication overflow protection is provided by Solidity 0.8.x.
        uint256 product = a * b;

        // Equivalent to:
        // result = product == 0 ? 0 : ((product - 1) / FixedPoint.ONE) + 1
        assembly ("memory-safe") {
            result := mul(iszero(iszero(product)), add(div(sub(product, 1), ONE), 1))
        }
    }

    function divDown(uint256 a, uint256 b) internal pure returns (uint256) {
        // Solidity 0.8 reverts with a Panic code (0x11) if the multiplication overflows.
        uint256 aInflated = a * ONE;

        // Solidity 0.8 reverts with a "Division by Zero" Panic code (0x12) if b is zero
        return aInflated / b;
    }

    function divUp(uint256 a, uint256 b) internal pure returns (uint256 result) {
        return mulDivUp(a, ONE, b);
    }

    /// @dev Return (a * b) / c, rounding up.
    function mulDivUp(uint256 a, uint256 b, uint256 c) internal pure returns (uint256 result) {
        // This check is required because Yul's `div` doesn't revert on c==0.
        if (c == 0) {
            revert ZeroDivision();
        }

        // Multiple overflow protection is done by Solidity 0.8.x.
        uint256 product = a * b;

        // The traditional divUp formula is:
        // divUp(x, y) := (x + y - 1) / y
        // To avoid intermediate overflow in the addition, we distribute the division and get:
        // divUp(x, y) := (x - 1) / y + 1
        // Note that this requires x != 0, if x == 0 then the result is zero
        //
        // Equivalent to:
        // result = a == 0 ? 0 : (a * b - 1) / c + 1
        assembly ("memory-safe") {
            result := mul(iszero(iszero(product)), add(div(sub(product, 1), c), 1))
        }
    }

    /**
     * @dev Version of divUp when the input is raw (i.e., already "inflated"). For instance,
     * invariant * invariant (36 decimals) vs. invariant.mulDown(invariant) (18 decimal FP).
     * This can occur in calculations with many successive multiplications and divisions, and
     * we want to minimize the number of operations by avoiding unnecessary scaling by ONE.
     */
    function divUpRaw(uint256 a, uint256 b) internal pure returns (uint256 result) {
        // This check is required because Yul's `div` doesn't revert on b==0.
        if (b == 0) {
            revert ZeroDivision();
        }

        // Equivalent to:
        // result = a == 0 ? 0 : 1 + (a - 1) / b
        assembly ("memory-safe") {
            result := mul(iszero(iszero(a)), add(1, div(sub(a, 1), b)))
        }
    }

    /**
     * @dev Returns x^y, assuming both are fixed point numbers, rounding down. The result is guaranteed to not be above
     * the true value (that is, the error function expected - actual is always positive).
     */
    function powDown(uint256 x, uint256 y) internal pure returns (uint256) {
        // Optimize for when y equals 1.0, 2.0 or 4.0, as those are very simple to implement and occur often in 50/50
        // and 80/20 Weighted Pools
        if (y == ONE) {
            return x;
        } else if (y == TWO) {
            return mulDown(x, x);
        } else if (y == FOUR) {
            uint256 square = mulDown(x, x);
            return mulDown(square, square);
        } else {
            uint256 raw = LogExpMath.pow(x, y);
            uint256 maxError = mulUp(raw, MAX_POW_RELATIVE_ERROR) + 1;

            if (raw < maxError) {
                return 0;
            } else {
                unchecked {
                    return raw - maxError;
                }
            }
        }
    }

    /**
     * @dev Returns x^y, assuming both are fixed point numbers, rounding up. The result is guaranteed to not be below
     * the true value (that is, the error function expected - actual is always negative).
     */
    function powUp(uint256 x, uint256 y) internal pure returns (uint256) {
        // Optimize for when y equals 1.0, 2.0 or 4.0, as those are very simple to implement and occur often in 50/50
        // and 80/20 Weighted Pools
        if (y == ONE) {
            return x;
        } else if (y == TWO) {
            return mulUp(x, x);
        } else if (y == FOUR) {
            uint256 square = mulUp(x, x);
            return mulUp(square, square);
        } else {
            uint256 raw = LogExpMath.pow(x, y);
            uint256 maxError = mulUp(raw, MAX_POW_RELATIVE_ERROR) + 1;

            return raw + maxError;
        }
    }

    /**
     * @dev Returns the complement of a value (1 - x), capped to 0 if x is larger than 1.
     *
     * Useful when computing the complement for values with some level of relative error, as it strips this error and
     * prevents intermediate negative values.
     */
    function complement(uint256 x) internal pure returns (uint256 result) {
        // Equivalent to:
        // result = (x < ONE) ? (ONE - x) : 0
        assembly ("memory-safe") {
            result := mul(lt(x, ONE), sub(ONE, x))
        }
    }
}


// File: @balancer-labs/v3-solidity-utils/contracts/math/LogExpMath.sol

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

// solhint-disable

/**
 * @dev Exponentiation and logarithm functions for 18 decimal fixed point numbers (both base and exponent/argument).
 *
 * Exponentiation and logarithm with arbitrary bases (x^y and log_x(y)) are implemented by conversion to natural
 * exponentiation and logarithm (where the base is Euler's number).
 *
 * All math operations are unchecked in order to save gas.
 *
 * @author Fernando Martinelli - @fernandomartinelli
 * @author Sergio Yuhjtman     - @sergioyuhjtman
 * @author Daniel Fernandez    - @dmf7z
 */
library LogExpMath {
    /// @notice This error is thrown when a base is not within an acceptable range.
    error BaseOutOfBounds();

    /// @notice This error is thrown when a exponent is not within an acceptable range.
    error ExponentOutOfBounds();

    /// @notice This error is thrown when the exponent * ln(base) is not within an acceptable range.
    error ProductOutOfBounds();

    /// @notice This error is thrown when an exponent used in the exp function is not within an acceptable range.
    error InvalidExponent();

    /// @notice This error is thrown when a variable or result is not within the acceptable bounds defined in the function.
    error OutOfBounds();

    // All fixed point multiplications and divisions are inlined. This means we need to divide by ONE when multiplying
    // two numbers, and multiply by ONE when dividing them.

    // All arguments and return values are 18 decimal fixed point numbers.
    int256 constant ONE_18 = 1e18;

    // Internally, intermediate values are computed with higher precision as 20 decimal fixed point numbers, and in the
    // case of ln36, 36 decimals.
    int256 constant ONE_20 = 1e20;
    int256 constant ONE_36 = 1e36;

    // The domain of natural exponentiation is bound by the word size and number of decimals used.
    //
    // Because internally the result will be stored using 20 decimals, the largest possible result is
    // (2^255 - 1) / 10^20, which makes the largest exponent ln((2^255 - 1) / 10^20) = 130.700829182905140221.
    // The smallest possible result is 10^(-18), which makes largest negative argument
    // ln(10^(-18)) = -41.446531673892822312.
    // We use 130.0 and -41.0 to have some safety margin.
    int256 constant MAX_NATURAL_EXPONENT = 130e18;
    int256 constant MIN_NATURAL_EXPONENT = -41e18;

    // Bounds for ln_36's argument. Both ln(0.9) and ln(1.1) can be represented with 36 decimal places in a fixed point
    // 256 bit integer.
    int256 constant LN_36_LOWER_BOUND = ONE_18 - 1e17;
    int256 constant LN_36_UPPER_BOUND = ONE_18 + 1e17;

    uint256 constant MILD_EXPONENT_BOUND = 2 ** 254 / uint256(ONE_20);

    // 18 decimal constants
    int256 constant x0 = 128000000000000000000; // 2ˆ7
    int256 constant a0 = 38877084059945950922200000000000000000000000000000000000; // eˆ(x0) (no decimals)
    int256 constant x1 = 64000000000000000000; // 2ˆ6
    int256 constant a1 = 6235149080811616882910000000; // eˆ(x1) (no decimals)

    // 20 decimal constants
    int256 constant x2 = 3200000000000000000000; // 2ˆ5
    int256 constant a2 = 7896296018268069516100000000000000; // eˆ(x2)
    int256 constant x3 = 1600000000000000000000; // 2ˆ4
    int256 constant a3 = 888611052050787263676000000; // eˆ(x3)
    int256 constant x4 = 800000000000000000000; // 2ˆ3
    int256 constant a4 = 298095798704172827474000; // eˆ(x4)
    int256 constant x5 = 400000000000000000000; // 2ˆ2
    int256 constant a5 = 5459815003314423907810; // eˆ(x5)
    int256 constant x6 = 200000000000000000000; // 2ˆ1
    int256 constant a6 = 738905609893065022723; // eˆ(x6)
    int256 constant x7 = 100000000000000000000; // 2ˆ0
    int256 constant a7 = 271828182845904523536; // eˆ(x7)
    int256 constant x8 = 50000000000000000000; // 2ˆ-1
    int256 constant a8 = 164872127070012814685; // eˆ(x8)
    int256 constant x9 = 25000000000000000000; // 2ˆ-2
    int256 constant a9 = 128402541668774148407; // eˆ(x9)
    int256 constant x10 = 12500000000000000000; // 2ˆ-3
    int256 constant a10 = 113314845306682631683; // eˆ(x10)
    int256 constant x11 = 6250000000000000000; // 2ˆ-4
    int256 constant a11 = 106449445891785942956; // eˆ(x11)

    /**
     * @dev Exponentiation (x^y) with unsigned 18 decimal fixed point base and exponent.
     *
     * Reverts if ln(x) * y is smaller than `MIN_NATURAL_EXPONENT`, or larger than `MAX_NATURAL_EXPONENT`.
     */
    function pow(uint256 x, uint256 y) internal pure returns (uint256) {
        if (y == 0) {
            // We solve the 0^0 indetermination by making it equal one.
            return uint256(ONE_18);
        }

        if (x == 0) {
            return 0;
        }

        // Instead of computing x^y directly, we instead rely on the properties of logarithms and exponentiation to
        // arrive at that result. In particular, exp(ln(x)) = x, and ln(x^y) = y * ln(x). This means
        // x^y = exp(y * ln(x)).

        // The ln function takes a signed value, so we need to make sure x fits in the signed 256 bit range.
        if (x >> 255 != 0) {
            revert BaseOutOfBounds();
        }
        int256 x_int256 = int256(x);

        // We will compute y * ln(x) in a single step. Depending on the value of x, we can either use ln or ln_36. In
        // both cases, we leave the division by ONE_18 (due to fixed point multiplication) to the end.

        // This prevents y * ln(x) from overflowing, and at the same time guarantees y fits in the signed 256 bit range.
        if (y >= MILD_EXPONENT_BOUND) {
            revert ExponentOutOfBounds();
        }
        int256 y_int256 = int256(y);

        int256 logx_times_y;
        unchecked {
            if (LN_36_LOWER_BOUND < x_int256 && x_int256 < LN_36_UPPER_BOUND) {
                int256 ln_36_x = _ln_36(x_int256);

                // ln_36_x has 36 decimal places, so multiplying by y_int256 isn't as straightforward, since we can't just
                // bring y_int256 to 36 decimal places, as it might overflow. Instead, we perform two 18 decimal
                // multiplications and add the results: one with the first 18 decimals of ln_36_x, and one with the
                // (downscaled) last 18 decimals.
                logx_times_y = ((ln_36_x / ONE_18) * y_int256 + ((ln_36_x % ONE_18) * y_int256) / ONE_18);
            } else {
                logx_times_y = _ln(x_int256) * y_int256;
            }
            logx_times_y /= ONE_18;
        }

        // Finally, we compute exp(y * ln(x)) to arrive at x^y
        if (!(MIN_NATURAL_EXPONENT <= logx_times_y && logx_times_y <= MAX_NATURAL_EXPONENT)) {
            revert ProductOutOfBounds();
        }

        return uint256(exp(logx_times_y));
    }

    /**
     * @dev Natural exponentiation (e^x) with signed 18 decimal fixed point exponent.
     *
     * Reverts if `x` is smaller than MIN_NATURAL_EXPONENT, or larger than `MAX_NATURAL_EXPONENT`.
     */
    function exp(int256 x) internal pure returns (int256) {
        if (!(x >= MIN_NATURAL_EXPONENT && x <= MAX_NATURAL_EXPONENT)) {
            revert InvalidExponent();
        }

        // We avoid using recursion here because zkSync doesn't support it.
        bool negativeExponent = false;

        if (x < 0) {
            // We only handle positive exponents: e^(-x) is computed as 1 / e^x. We can safely make x positive since it
            // fits in the signed 256 bit range (as it is larger than MIN_NATURAL_EXPONENT). In the negative
            // exponent case, compute e^x, then return 1 / result.
            unchecked {
                x = -x;
            }
            negativeExponent = true;
        }

        // First, we use the fact that e^(x+y) = e^x * e^y to decompose x into a sum of powers of two, which we call x_n,
        // where x_n == 2^(7 - n), and e^x_n = a_n has been precomputed. We choose the first x_n, x0, to equal 2^7
        // because all larger powers are larger than MAX_NATURAL_EXPONENT, and therefore not present in the
        // decomposition.
        // At the end of this process we will have the product of all e^x_n = a_n that apply, and the remainder of this
        // decomposition, which will be lower than the smallest x_n.
        // exp(x) = k_0 * a_0 * k_1 * a_1 * ... + k_n * a_n * exp(remainder), where each k_n equals either 0 or 1.
        // We mutate x by subtracting x_n, making it the remainder of the decomposition.

        // The first two a_n (e^(2^7) and e^(2^6)) are too large if stored as 18 decimal numbers, and could cause
        // intermediate overflows. Instead we store them as plain integers, with 0 decimals.
        // Additionally, x0 + x1 is larger than MAX_NATURAL_EXPONENT, which means they will not both be present in the
        // decomposition.

        // For each x_n, we test if that term is present in the decomposition (if x is larger than it), and if so deduct
        // it and compute the accumulated product.

        int256 firstAN;
        unchecked {
            if (x >= x0) {
                x -= x0;
                firstAN = a0;
            } else if (x >= x1) {
                x -= x1;
                firstAN = a1;
            } else {
                firstAN = 1; // One with no decimal places
            }

            // We now transform x into a 20 decimal fixed point number, to have enhanced precision when computing the
            // smaller terms.
            x *= 100;
        }

        // `product` is the accumulated product of all a_n (except a0 and a1), which starts at 20 decimal fixed point
        // one. Recall that fixed point multiplication requires dividing by ONE_20.
        int256 product = ONE_20;

        unchecked {
            if (x >= x2) {
                x -= x2;
                product = (product * a2) / ONE_20;
            }
            if (x >= x3) {
                x -= x3;
                product = (product * a3) / ONE_20;
            }
            if (x >= x4) {
                x -= x4;
                product = (product * a4) / ONE_20;
            }
            if (x >= x5) {
                x -= x5;
                product = (product * a5) / ONE_20;
            }
            if (x >= x6) {
                x -= x6;
                product = (product * a6) / ONE_20;
            }
            if (x >= x7) {
                x -= x7;
                product = (product * a7) / ONE_20;
            }
            if (x >= x8) {
                x -= x8;
                product = (product * a8) / ONE_20;
            }
            if (x >= x9) {
                x -= x9;
                product = (product * a9) / ONE_20;
            }
        }

        // x10 and x11 are unnecessary here since we have high enough precision already.

        // Now we need to compute e^x, where x is small (in particular, it is smaller than x9). We use the Taylor series
        // expansion for e^x: 1 + x + (x^2 / 2!) + (x^3 / 3!) + ... + (x^n / n!).

        int256 seriesSum = ONE_20; // The initial one in the sum, with 20 decimal places.
        int256 term; // Each term in the sum, where the nth term is (x^n / n!).

        // The first term is simply x.
        term = x;
        unchecked {
            seriesSum += term;

            // Each term (x^n / n!) equals the previous one times x, divided by n. Since x is a fixed point number,
            // multiplying by it requires dividing by ONE_20, but dividing by the non-fixed point n values does not.

            term = ((term * x) / ONE_20) / 2;
            seriesSum += term;

            term = ((term * x) / ONE_20) / 3;
            seriesSum += term;

            term = ((term * x) / ONE_20) / 4;
            seriesSum += term;

            term = ((term * x) / ONE_20) / 5;
            seriesSum += term;

            term = ((term * x) / ONE_20) / 6;
            seriesSum += term;

            term = ((term * x) / ONE_20) / 7;
            seriesSum += term;

            term = ((term * x) / ONE_20) / 8;
            seriesSum += term;

            term = ((term * x) / ONE_20) / 9;
            seriesSum += term;

            term = ((term * x) / ONE_20) / 10;
            seriesSum += term;

            term = ((term * x) / ONE_20) / 11;
            seriesSum += term;

            term = ((term * x) / ONE_20) / 12;
            seriesSum += term;

            // 12 Taylor terms are sufficient for 18 decimal precision.

            // We now have the first a_n (with no decimals), and the product of all other a_n present, and the Taylor
            // approximation of the exponentiation of the remainder (both with 20 decimals). All that remains is to multiply
            // all three (one 20 decimal fixed point multiplication, dividing by ONE_20, and one integer multiplication),
            // and then drop two digits to return an 18 decimal value.

            int256 result = (((product * seriesSum) / ONE_20) * firstAN) / 100;

            // We avoid using recursion here because zkSync doesn't support it.
            return negativeExponent ? (ONE_18 * ONE_18) / result : result;
        }
    }

    /// @dev Logarithm (log(arg, base), with signed 18 decimal fixed point base and argument.
    function log(int256 arg, int256 base) internal pure returns (int256) {
        // This performs a simple base change: log(arg, base) = ln(arg) / ln(base).

        // Both logBase and logArg are computed as 36 decimal fixed point numbers, either by using ln_36, or by
        // upscaling.

        int256 logBase;
        unchecked {
            if (LN_36_LOWER_BOUND < base && base < LN_36_UPPER_BOUND) {
                logBase = _ln_36(base);
            } else {
                logBase = _ln(base) * ONE_18;
            }
        }

        int256 logArg;
        unchecked {
            if (LN_36_LOWER_BOUND < arg && arg < LN_36_UPPER_BOUND) {
                logArg = _ln_36(arg);
            } else {
                logArg = _ln(arg) * ONE_18;
            }

            // When dividing, we multiply by ONE_18 to arrive at a result with 18 decimal places
            return (logArg * ONE_18) / logBase;
        }
    }

    /// @dev Natural logarithm (ln(a)) with signed 18 decimal fixed point argument.
    function ln(int256 a) internal pure returns (int256) {
        // The real natural logarithm is not defined for negative numbers or zero.
        if (a <= 0) {
            revert OutOfBounds();
        }
        if (LN_36_LOWER_BOUND < a && a < LN_36_UPPER_BOUND) {
            unchecked {
                return _ln_36(a) / ONE_18;
            }
        } else {
            return _ln(a);
        }
    }

    /// @dev Internal natural logarithm (ln(a)) with signed 18 decimal fixed point argument.
    function _ln(int256 a) private pure returns (int256) {
        // We avoid using recursion here because zkSync doesn't support it.
        bool negativeExponent = false;

        if (a < ONE_18) {
            // Since ln(a^k) = k * ln(a), we can compute ln(a) as ln(a) = ln((1/a)^(-1)) = - ln((1/a)). If a is less
            // than one, 1/a will be greater than one, so in this case we compute ln(1/a) and negate the final result.
            unchecked {
                a = (ONE_18 * ONE_18) / a;
            }
            negativeExponent = true;
        }

        // First, we use the fact that ln^(a * b) = ln(a) + ln(b) to decompose ln(a) into a sum of powers of two, which
        // we call x_n, where x_n == 2^(7 - n), which are the natural logarithm of precomputed quantities a_n (that is,
        // ln(a_n) = x_n). We choose the first x_n, x0, to equal 2^7 because the exponential of all larger powers cannot
        // be represented as 18 fixed point decimal numbers in 256 bits, and are therefore larger than a.
        // At the end of this process we will have the sum of all x_n = ln(a_n) that apply, and the remainder of this
        // decomposition, which will be lower than the smallest a_n.
        // ln(a) = k_0 * x_0 + k_1 * x_1 + ... + k_n * x_n + ln(remainder), where each k_n equals either 0 or 1.
        // We mutate a by subtracting a_n, making it the remainder of the decomposition.

        // For reasons related to how `exp` works, the first two a_n (e^(2^7) and e^(2^6)) are not stored as fixed point
        // numbers with 18 decimals, but instead as plain integers with 0 decimals, so we need to multiply them by
        // ONE_18 to convert them to fixed point.
        // For each a_n, we test if that term is present in the decomposition (if a is larger than it), and if so divide
        // by it and compute the accumulated sum.

        int256 sum = 0;
        unchecked {
            if (a >= a0 * ONE_18) {
                a /= a0; // Integer, not fixed point division
                sum += x0;
            }

            if (a >= a1 * ONE_18) {
                a /= a1; // Integer, not fixed point division
                sum += x1;
            }

            // All other a_n and x_n are stored as 20 digit fixed point numbers, so we convert the sum and a to this format.
            sum *= 100;
            a *= 100;

            // Because further a_n are  20 digit fixed point numbers, we multiply by ONE_20 when dividing by them.

            if (a >= a2) {
                a = (a * ONE_20) / a2;
                sum += x2;
            }

            if (a >= a3) {
                a = (a * ONE_20) / a3;
                sum += x3;
            }

            if (a >= a4) {
                a = (a * ONE_20) / a4;
                sum += x4;
            }

            if (a >= a5) {
                a = (a * ONE_20) / a5;
                sum += x5;
            }

            if (a >= a6) {
                a = (a * ONE_20) / a6;
                sum += x6;
            }

            if (a >= a7) {
                a = (a * ONE_20) / a7;
                sum += x7;
            }

            if (a >= a8) {
                a = (a * ONE_20) / a8;
                sum += x8;
            }

            if (a >= a9) {
                a = (a * ONE_20) / a9;
                sum += x9;
            }

            if (a >= a10) {
                a = (a * ONE_20) / a10;
                sum += x10;
            }

            if (a >= a11) {
                a = (a * ONE_20) / a11;
                sum += x11;
            }
        }

        // a is now a small number (smaller than a_11, which roughly equals 1.06). This means we can use a Taylor series
        // that converges rapidly for values of `a` close to one - the same one used in ln_36.
        // Let z = (a - 1) / (a + 1).
        // ln(a) = 2 * (z + z^3 / 3 + z^5 / 5 + z^7 / 7 + ... + z^(2 * n + 1) / (2 * n + 1))

        // Recall that 20 digit fixed point division requires multiplying by ONE_20, and multiplication requires
        // division by ONE_20.
        unchecked {
            int256 z = ((a - ONE_20) * ONE_20) / (a + ONE_20);
            int256 z_squared = (z * z) / ONE_20;

            // num is the numerator of the series: the z^(2 * n + 1) term
            int256 num = z;

            // seriesSum holds the accumulated sum of each term in the series, starting with the initial z
            int256 seriesSum = num;

            // In each step, the numerator is multiplied by z^2
            num = (num * z_squared) / ONE_20;
            seriesSum += num / 3;

            num = (num * z_squared) / ONE_20;
            seriesSum += num / 5;

            num = (num * z_squared) / ONE_20;
            seriesSum += num / 7;

            num = (num * z_squared) / ONE_20;
            seriesSum += num / 9;

            num = (num * z_squared) / ONE_20;
            seriesSum += num / 11;

            // 6 Taylor terms are sufficient for 36 decimal precision.

            // Finally, we multiply by 2 (non fixed point) to compute ln(remainder)
            seriesSum *= 2;

            // We now have the sum of all x_n present, and the Taylor approximation of the logarithm of the remainder (both
            // with 20 decimals). All that remains is to sum these two, and then drop two digits to return a 18 decimal
            // value.

            int256 result = (sum + seriesSum) / 100;

            // We avoid using recursion here because zkSync doesn't support it.
            return negativeExponent ? -result : result;
        }
    }

    /**
     * @dev Internal high precision (36 decimal places) natural logarithm (ln(x)) with signed 18 decimal fixed point argument,
     * for x close to one.
     *
     * Should only be used if x is between LN_36_LOWER_BOUND and LN_36_UPPER_BOUND.
     */
    function _ln_36(int256 x) private pure returns (int256) {
        // Since ln(1) = 0, a value of x close to one will yield a very small result, which makes using 36 digits
        // worthwhile.

        // First, we transform x to a 36 digit fixed point value.
        unchecked {
            x *= ONE_18;

            // We will use the following Taylor expansion, which converges very rapidly. Let z = (x - 1) / (x + 1).
            // ln(x) = 2 * (z + z^3 / 3 + z^5 / 5 + z^7 / 7 + ... + z^(2 * n + 1) / (2 * n + 1))

            // Recall that 36 digit fixed point division requires multiplying by ONE_36, and multiplication requires
            // division by ONE_36.
            int256 z = ((x - ONE_36) * ONE_36) / (x + ONE_36);
            int256 z_squared = (z * z) / ONE_36;

            // num is the numerator of the series: the z^(2 * n + 1) term
            int256 num = z;

            // seriesSum holds the accumulated sum of each term in the series, starting with the initial z
            int256 seriesSum = num;

            // In each step, the numerator is multiplied by z^2
            num = (num * z_squared) / ONE_36;
            seriesSum += num / 3;

            num = (num * z_squared) / ONE_36;
            seriesSum += num / 5;

            num = (num * z_squared) / ONE_36;
            seriesSum += num / 7;

            num = (num * z_squared) / ONE_36;
            seriesSum += num / 9;

            num = (num * z_squared) / ONE_36;
            seriesSum += num / 11;

            num = (num * z_squared) / ONE_36;
            seriesSum += num / 13;

            num = (num * z_squared) / ONE_36;
            seriesSum += num / 15;

            // 8 Taylor terms are sufficient for 36 decimal precision.

            // All that remains is multiplying by 2 (non fixed point).
            return seriesSum * 2;
        }
    }
}


// File: @balancer-labs/v3-solidity-utils/contracts/openzeppelin/ReentrancyGuardTransient.sol

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import { StorageSlotExtension } from "./StorageSlotExtension.sol";

/**
 * @notice Variant of {ReentrancyGuard} that uses transient storage.
 * @dev NOTE: This variant only works on networks where EIP-1153 is available.
 */
abstract contract ReentrancyGuardTransient {
    using StorageSlotExtension for *;

    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.ReentrancyGuard")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant _REENTRANCY_GUARD_STORAGE =
        0x9b779b17422d0df92223018b32b4d1fa46e071723d6817e2486d003becc55f00;

    /// @notice Unauthorized reentrant call.
    error ReentrancyGuardReentrantCall();

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        // On the first call to nonReentrant, _status will be NOT_ENTERED.
        if (_reentrancyGuardEntered()) {
            revert ReentrancyGuardReentrantCall();
        }

        // Any calls to nonReentrant after this point will fail.
        _REENTRANCY_GUARD_STORAGE.asBoolean().tstore(true);
    }

    function _nonReentrantAfter() private {
        _REENTRANCY_GUARD_STORAGE.asBoolean().tstore(false);
    }

    /**
     * @dev Returns true if the reentrancy guard is currently set to "entered", which indicates there is a
     * `nonReentrant` function in the call stack.
     */
    function _reentrancyGuardEntered() internal view returns (bool) {
        return _REENTRANCY_GUARD_STORAGE.asBoolean().tload();
    }
}


// File: @balancer-labs/v3-solidity-utils/contracts/openzeppelin/SlotDerivation.sol

// SPDX-License-Identifier: MIT
// This file was procedurally generated from scripts/generate/templates/SlotDerivation.js.

// Taken from https://raw.githubusercontent.com/Amxx/openzeppelin-contracts/ce497cb05ca05bb9aa2b86ec1d99e6454e7ab2e9/contracts/utils/SlotDerivation.sol

pragma solidity ^0.8.20;

/**
 * @notice Library for computing storage (and transient storage) locations from namespaces and deriving slots
 * corresponding to standard patterns.
 * @dev The derivation method for array and mapping matches the storage layout used by the solidity language/compiler.
 *
 * See https://docs.soliditylang.org/en/v0.8.20/internals/layout_in_storage.html#mappings-and-dynamic-arrays[Solidity docs for mappings and dynamic arrays.].
 *
 * Example usage:
 * ```solidity
 * contract Example {
 *     // Add the library methods
 *     using StorageSlot for bytes32;
 *     using SlotDerivation for bytes32;
 *
 *     // Declare a namespace
 *     string private constant _NAMESPACE = "<namespace>" // eg. OpenZeppelin.Slot
 *
 *     function setValueInNamespace(uint256 key, address newValue) internal {
 *         _NAMESPACE.erc7201Slot().deriveMapping(key).getAddressSlot().value = newValue;
 *     }
 *
 *     function getValueInNamespace(uint256 key) internal view returns (address) {
 *         return _NAMESPACE.erc7201Slot().deriveMapping(key).getAddressSlot().value;
 *     }
 * }
 * ```
 *
 * TIP: Consider using this library along with {StorageSlot}.
 *
 * NOTE: This library provides a way to manipulate storage locations in a non-standard way. Tooling for checking
 * upgrade safety will ignore the slots accessed through this library.
 */
library SlotDerivation {
    /// @dev Derive an ERC-7201 slot from a string (namespace).
    function erc7201Slot(string memory namespace) internal pure returns (bytes32 slot) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, sub(keccak256(add(namespace, 0x20), mload(namespace)), 1))
            slot := and(keccak256(0x00, 0x20), not(0xff))
        }
    }

    /// @dev Add an offset to a slot to get the n-th element of a structure or an array.
    function offset(bytes32 slot, uint256 pos) internal pure returns (bytes32 result) {
        unchecked {
            return bytes32(uint256(slot) + pos);
        }
    }

    /// @dev Derive the location of the first element in an array from the slot where the length is stored.
    function deriveArray(bytes32 slot) internal pure returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, slot)
            result := keccak256(0x00, 0x20)
        }
    }

    /// @dev Derive the location of a mapping element from the key.
    function deriveMapping(bytes32 slot, address key) internal pure returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, key)
            mstore(0x20, slot)
            result := keccak256(0x00, 0x40)
        }
    }

    /// @dev Derive the location of a mapping element from the key.
    function deriveMapping(bytes32 slot, bool key) internal pure returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, key)
            mstore(0x20, slot)
            result := keccak256(0x00, 0x40)
        }
    }

    /// @dev Derive the location of a mapping element from the key.
    function deriveMapping(bytes32 slot, bytes32 key) internal pure returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, key)
            mstore(0x20, slot)
            result := keccak256(0x00, 0x40)
        }
    }

    /// @dev Derive the location of a mapping element from the key.
    function deriveMapping(bytes32 slot, uint256 key) internal pure returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, key)
            mstore(0x20, slot)
            result := keccak256(0x00, 0x40)
        }
    }

    /// @dev Derive the location of a mapping element from the key.
    function deriveMapping(bytes32 slot, int256 key) internal pure returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, key)
            mstore(0x20, slot)
            result := keccak256(0x00, 0x40)
        }
    }

    /// @dev Derive the location of a mapping element from the key.
    function deriveMapping(bytes32 slot, string memory key) internal pure returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            let length := mload(key)
            let begin := add(key, 0x20)
            let end := add(begin, length)
            let cache := mload(end)
            mstore(end, slot)
            result := keccak256(begin, add(length, 0x20))
            mstore(end, cache)
        }
    }

    /// @dev Derive the location of a mapping element from the key.
    function deriveMapping(bytes32 slot, bytes memory key) internal pure returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            let length := mload(key)
            let begin := add(key, 0x20)
            let end := add(begin, length)
            let cache := mload(end)
            mstore(end, slot)
            result := keccak256(begin, add(length, 0x20))
            mstore(end, cache)
        }
    }
}

// File: @balancer-labs/v3-solidity-utils/contracts/openzeppelin/StorageSlotExtension.sol

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

/**
 * @notice Library for reading and writing primitive types to specific storage slots. Based on OpenZeppelin; just adding support for int256.
 * @dev TIP: Consider using this library along with {SlotDerivation}.
 */
library StorageSlotExtension {
    struct Int256Slot {
        int256 value;
    }

    /// @dev Returns an `Int256Slot` with member `value` located at `slot`.
    function getInt256Slot(bytes32 slot) internal pure returns (Int256Slot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /// @dev Custom type that represents a slot holding an address.
    type AddressSlotType is bytes32;

    /// @dev Cast an arbitrary slot to a AddressSlotType.
    function asAddress(bytes32 slot) internal pure returns (AddressSlotType) {
        return AddressSlotType.wrap(slot);
    }

    /// @dev Custom type that represents a slot holding a boolean.
    type BooleanSlotType is bytes32;

    /// @dev Cast an arbitrary slot to a BooleanSlotType.
    function asBoolean(bytes32 slot) internal pure returns (BooleanSlotType) {
        return BooleanSlotType.wrap(slot);
    }

    /// @dev Custom type that represents a slot holding a bytes32.
    type Bytes32SlotType is bytes32;

    /// @dev Cast an arbitrary slot to a Bytes32SlotType.
    function asBytes32(bytes32 slot) internal pure returns (Bytes32SlotType) {
        return Bytes32SlotType.wrap(slot);
    }

    /// @dev Custom type that represents a slot holding a uint256.
    type Uint256SlotType is bytes32;

    /// @dev Cast an arbitrary slot to a Uint256SlotType.
    function asUint256(bytes32 slot) internal pure returns (Uint256SlotType) {
        return Uint256SlotType.wrap(slot);
    }

    /// @dev Custom type that represents a slot holding an int256.
    type Int256SlotType is bytes32;

    /// @dev Cast an arbitrary slot to an Int256SlotType.
    function asInt256(bytes32 slot) internal pure returns (Int256SlotType) {
        return Int256SlotType.wrap(slot);
    }

    /// @dev Load the value held at location `slot` in transient storage.
    function tload(AddressSlotType slot) internal view returns (address value) {
        /// @solidity memory-safe-assembly
        assembly {
            value := tload(slot)
        }
    }

    /// @dev Store `value` at location `slot` in transient storage.
    function tstore(AddressSlotType slot, address value) internal {
        /// @solidity memory-safe-assembly
        assembly {
            tstore(slot, value)
        }
    }

    /// @dev Load the value held at location `slot` in transient storage.
    function tload(BooleanSlotType slot) internal view returns (bool value) {
        /// @solidity memory-safe-assembly
        assembly {
            value := tload(slot)
        }
    }

    /// @dev Store `value` at location `slot` in transient storage.
    function tstore(BooleanSlotType slot, bool value) internal {
        /// @solidity memory-safe-assembly
        assembly {
            tstore(slot, value)
        }
    }

    /// @dev Load the value held at location `slot` in transient storage.
    function tload(Bytes32SlotType slot) internal view returns (bytes32 value) {
        /// @solidity memory-safe-assembly
        assembly {
            value := tload(slot)
        }
    }

    /// @dev Store `value` at location `slot` in transient storage.
    function tstore(Bytes32SlotType slot, bytes32 value) internal {
        /// @solidity memory-safe-assembly
        assembly {
            tstore(slot, value)
        }
    }

    /// @dev Load the value held at location `slot` in transient storage.
    function tload(Uint256SlotType slot) internal view returns (uint256 value) {
        /// @solidity memory-safe-assembly
        assembly {
            value := tload(slot)
        }
    }

    /// @dev Store `value` at location `slot` in transient storage.
    function tstore(Uint256SlotType slot, uint256 value) internal {
        /// @solidity memory-safe-assembly
        assembly {
            tstore(slot, value)
        }
    }

    /// @dev Load the value held at location `slot` in transient storage.
    function tload(Int256SlotType slot) internal view returns (int256 value) {
        /// @solidity memory-safe-assembly
        assembly {
            value := tload(slot)
        }
    }

    /// @dev Store `value` at location `slot` in transient storage.
    function tstore(Int256SlotType slot, int256 value) internal {
        /// @solidity memory-safe-assembly
        assembly {
            tstore(slot, value)
        }
    }
}


// File: @openzeppelin/contracts/interfaces/draft-IERC6093.sol

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (interfaces/draft-IERC6093.sol)
pragma solidity ^0.8.20;

/**
 * @dev Standard ERC20 Errors
 * Interface of the https://eips.ethereum.org/EIPS/eip-6093[ERC-6093] custom errors for ERC20 tokens.
 */
interface IERC20Errors {
    /**
     * @dev Indicates an error related to the current `balance` of a `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     * @param balance Current balance for the interacting account.
     * @param needed Minimum amount required to perform a transfer.
     */
    error ERC20InsufficientBalance(address sender, uint256 balance, uint256 needed);

    /**
     * @dev Indicates a failure with the token `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     */
    error ERC20InvalidSender(address sender);

    /**
     * @dev Indicates a failure with the token `receiver`. Used in transfers.
     * @param receiver Address to which tokens are being transferred.
     */
    error ERC20InvalidReceiver(address receiver);

    /**
     * @dev Indicates a failure with the `spender`’s `allowance`. Used in transfers.
     * @param spender Address that may be allowed to operate on tokens without being their owner.
     * @param allowance Amount of tokens a `spender` is allowed to operate with.
     * @param needed Minimum amount required to perform a transfer.
     */
    error ERC20InsufficientAllowance(address spender, uint256 allowance, uint256 needed);

    /**
     * @dev Indicates a failure with the `approver` of a token to be approved. Used in approvals.
     * @param approver Address initiating an approval operation.
     */
    error ERC20InvalidApprover(address approver);

    /**
     * @dev Indicates a failure with the `spender` to be approved. Used in approvals.
     * @param spender Address that may be allowed to operate on tokens without being their owner.
     */
    error ERC20InvalidSpender(address spender);
}

/**
 * @dev Standard ERC721 Errors
 * Interface of the https://eips.ethereum.org/EIPS/eip-6093[ERC-6093] custom errors for ERC721 tokens.
 */
interface IERC721Errors {
    /**
     * @dev Indicates that an address can't be an owner. For example, `address(0)` is a forbidden owner in EIP-20.
     * Used in balance queries.
     * @param owner Address of the current owner of a token.
     */
    error ERC721InvalidOwner(address owner);

    /**
     * @dev Indicates a `tokenId` whose `owner` is the zero address.
     * @param tokenId Identifier number of a token.
     */
    error ERC721NonexistentToken(uint256 tokenId);

    /**
     * @dev Indicates an error related to the ownership over a particular token. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     * @param tokenId Identifier number of a token.
     * @param owner Address of the current owner of a token.
     */
    error ERC721IncorrectOwner(address sender, uint256 tokenId, address owner);

    /**
     * @dev Indicates a failure with the token `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     */
    error ERC721InvalidSender(address sender);

    /**
     * @dev Indicates a failure with the token `receiver`. Used in transfers.
     * @param receiver Address to which tokens are being transferred.
     */
    error ERC721InvalidReceiver(address receiver);

    /**
     * @dev Indicates a failure with the `operator`’s approval. Used in transfers.
     * @param operator Address that may be allowed to operate on tokens without being their owner.
     * @param tokenId Identifier number of a token.
     */
    error ERC721InsufficientApproval(address operator, uint256 tokenId);

    /**
     * @dev Indicates a failure with the `approver` of a token to be approved. Used in approvals.
     * @param approver Address initiating an approval operation.
     */
    error ERC721InvalidApprover(address approver);

    /**
     * @dev Indicates a failure with the `operator` to be approved. Used in approvals.
     * @param operator Address that may be allowed to operate on tokens without being their owner.
     */
    error ERC721InvalidOperator(address operator);
}

/**
 * @dev Standard ERC1155 Errors
 * Interface of the https://eips.ethereum.org/EIPS/eip-6093[ERC-6093] custom errors for ERC1155 tokens.
 */
interface IERC1155Errors {
    /**
     * @dev Indicates an error related to the current `balance` of a `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     * @param balance Current balance for the interacting account.
     * @param needed Minimum amount required to perform a transfer.
     * @param tokenId Identifier number of a token.
     */
    error ERC1155InsufficientBalance(address sender, uint256 balance, uint256 needed, uint256 tokenId);

    /**
     * @dev Indicates a failure with the token `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     */
    error ERC1155InvalidSender(address sender);

    /**
     * @dev Indicates a failure with the token `receiver`. Used in transfers.
     * @param receiver Address to which tokens are being transferred.
     */
    error ERC1155InvalidReceiver(address receiver);

    /**
     * @dev Indicates a failure with the `operator`’s approval. Used in transfers.
     * @param operator Address that may be allowed to operate on tokens without being their owner.
     * @param owner Address of the current owner of a token.
     */
    error ERC1155MissingApprovalForAll(address operator, address owner);

    /**
     * @dev Indicates a failure with the `approver` of a token to be approved. Used in approvals.
     * @param approver Address initiating an approval operation.
     */
    error ERC1155InvalidApprover(address approver);

    /**
     * @dev Indicates a failure with the `operator` to be approved. Used in approvals.
     * @param operator Address that may be allowed to operate on tokens without being their owner.
     */
    error ERC1155InvalidOperator(address operator);

    /**
     * @dev Indicates an array length mismatch between ids and values in a safeBatchTransferFrom operation.
     * Used in batch transfers.
     * @param idsLength Length of the array of token identifiers
     * @param valuesLength Length of the array of token amounts
     */
    error ERC1155InvalidArrayLength(uint256 idsLength, uint256 valuesLength);
}


// File: @openzeppelin/contracts/interfaces/IERC4626.sol

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (interfaces/IERC4626.sol)

pragma solidity ^0.8.20;

import {IERC20} from "../token/ERC20/IERC20.sol";
import {IERC20Metadata} from "../token/ERC20/extensions/IERC20Metadata.sol";

/**
 * @dev Interface of the ERC4626 "Tokenized Vault Standard", as defined in
 * https://eips.ethereum.org/EIPS/eip-4626[ERC-4626].
 */
interface IERC4626 is IERC20, IERC20Metadata {
    event Deposit(address indexed sender, address indexed owner, uint256 assets, uint256 shares);

    event Withdraw(
        address indexed sender,
        address indexed receiver,
        address indexed owner,
        uint256 assets,
        uint256 shares
    );

    /**
     * @dev Returns the address of the underlying token used for the Vault for accounting, depositing, and withdrawing.
     *
     * - MUST be an ERC-20 token contract.
     * - MUST NOT revert.
     */
    function asset() external view returns (address assetTokenAddress);

    /**
     * @dev Returns the total amount of the underlying asset that is “managed” by Vault.
     *
     * - SHOULD include any compounding that occurs from yield.
     * - MUST be inclusive of any fees that are charged against assets in the Vault.
     * - MUST NOT revert.
     */
    function totalAssets() external view returns (uint256 totalManagedAssets);

    /**
     * @dev Returns the amount of shares that the Vault would exchange for the amount of assets provided, in an ideal
     * scenario where all the conditions are met.
     *
     * - MUST NOT be inclusive of any fees that are charged against assets in the Vault.
     * - MUST NOT show any variations depending on the caller.
     * - MUST NOT reflect slippage or other on-chain conditions, when performing the actual exchange.
     * - MUST NOT revert.
     *
     * NOTE: This calculation MAY NOT reflect the “per-user” price-per-share, and instead should reflect the
     * “average-user’s” price-per-share, meaning what the average user should expect to see when exchanging to and
     * from.
     */
    function convertToShares(uint256 assets) external view returns (uint256 shares);

    /**
     * @dev Returns the amount of assets that the Vault would exchange for the amount of shares provided, in an ideal
     * scenario where all the conditions are met.
     *
     * - MUST NOT be inclusive of any fees that are charged against assets in the Vault.
     * - MUST NOT show any variations depending on the caller.
     * - MUST NOT reflect slippage or other on-chain conditions, when performing the actual exchange.
     * - MUST NOT revert.
     *
     * NOTE: This calculation MAY NOT reflect the “per-user” price-per-share, and instead should reflect the
     * “average-user’s” price-per-share, meaning what the average user should expect to see when exchanging to and
     * from.
     */
    function convertToAssets(uint256 shares) external view returns (uint256 assets);

    /**
     * @dev Returns the maximum amount of the underlying asset that can be deposited into the Vault for the receiver,
     * through a deposit call.
     *
     * - MUST return a limited value if receiver is subject to some deposit limit.
     * - MUST return 2 ** 256 - 1 if there is no limit on the maximum amount of assets that may be deposited.
     * - MUST NOT revert.
     */
    function maxDeposit(address receiver) external view returns (uint256 maxAssets);

    /**
     * @dev Allows an on-chain or off-chain user to simulate the effects of their deposit at the current block, given
     * current on-chain conditions.
     *
     * - MUST return as close to and no more than the exact amount of Vault shares that would be minted in a deposit
     *   call in the same transaction. I.e. deposit should return the same or more shares as previewDeposit if called
     *   in the same transaction.
     * - MUST NOT account for deposit limits like those returned from maxDeposit and should always act as though the
     *   deposit would be accepted, regardless if the user has enough tokens approved, etc.
     * - MUST be inclusive of deposit fees. Integrators should be aware of the existence of deposit fees.
     * - MUST NOT revert.
     *
     * NOTE: any unfavorable discrepancy between convertToShares and previewDeposit SHOULD be considered slippage in
     * share price or some other type of condition, meaning the depositor will lose assets by depositing.
     */
    function previewDeposit(uint256 assets) external view returns (uint256 shares);

    /**
     * @dev Mints shares Vault shares to receiver by depositing exactly amount of underlying tokens.
     *
     * - MUST emit the Deposit event.
     * - MAY support an additional flow in which the underlying tokens are owned by the Vault contract before the
     *   deposit execution, and are accounted for during deposit.
     * - MUST revert if all of assets cannot be deposited (due to deposit limit being reached, slippage, the user not
     *   approving enough underlying tokens to the Vault contract, etc).
     *
     * NOTE: most implementations will require pre-approval of the Vault with the Vault’s underlying asset token.
     */
    function deposit(uint256 assets, address receiver) external returns (uint256 shares);

    /**
     * @dev Returns the maximum amount of the Vault shares that can be minted for the receiver, through a mint call.
     * - MUST return a limited value if receiver is subject to some mint limit.
     * - MUST return 2 ** 256 - 1 if there is no limit on the maximum amount of shares that may be minted.
     * - MUST NOT revert.
     */
    function maxMint(address receiver) external view returns (uint256 maxShares);

    /**
     * @dev Allows an on-chain or off-chain user to simulate the effects of their mint at the current block, given
     * current on-chain conditions.
     *
     * - MUST return as close to and no fewer than the exact amount of assets that would be deposited in a mint call
     *   in the same transaction. I.e. mint should return the same or fewer assets as previewMint if called in the
     *   same transaction.
     * - MUST NOT account for mint limits like those returned from maxMint and should always act as though the mint
     *   would be accepted, regardless if the user has enough tokens approved, etc.
     * - MUST be inclusive of deposit fees. Integrators should be aware of the existence of deposit fees.
     * - MUST NOT revert.
     *
     * NOTE: any unfavorable discrepancy between convertToAssets and previewMint SHOULD be considered slippage in
     * share price or some other type of condition, meaning the depositor will lose assets by minting.
     */
    function previewMint(uint256 shares) external view returns (uint256 assets);

    /**
     * @dev Mints exactly shares Vault shares to receiver by depositing amount of underlying tokens.
     *
     * - MUST emit the Deposit event.
     * - MAY support an additional flow in which the underlying tokens are owned by the Vault contract before the mint
     *   execution, and are accounted for during mint.
     * - MUST revert if all of shares cannot be minted (due to deposit limit being reached, slippage, the user not
     *   approving enough underlying tokens to the Vault contract, etc).
     *
     * NOTE: most implementations will require pre-approval of the Vault with the Vault’s underlying asset token.
     */
    function mint(uint256 shares, address receiver) external returns (uint256 assets);

    /**
     * @dev Returns the maximum amount of the underlying asset that can be withdrawn from the owner balance in the
     * Vault, through a withdraw call.
     *
     * - MUST return a limited value if owner is subject to some withdrawal limit or timelock.
     * - MUST NOT revert.
     */
    function maxWithdraw(address owner) external view returns (uint256 maxAssets);

    /**
     * @dev Allows an on-chain or off-chain user to simulate the effects of their withdrawal at the current block,
     * given current on-chain conditions.
     *
     * - MUST return as close to and no fewer than the exact amount of Vault shares that would be burned in a withdraw
     *   call in the same transaction. I.e. withdraw should return the same or fewer shares as previewWithdraw if
     *   called
     *   in the same transaction.
     * - MUST NOT account for withdrawal limits like those returned from maxWithdraw and should always act as though
     *   the withdrawal would be accepted, regardless if the user has enough shares, etc.
     * - MUST be inclusive of withdrawal fees. Integrators should be aware of the existence of withdrawal fees.
     * - MUST NOT revert.
     *
     * NOTE: any unfavorable discrepancy between convertToShares and previewWithdraw SHOULD be considered slippage in
     * share price or some other type of condition, meaning the depositor will lose assets by depositing.
     */
    function previewWithdraw(uint256 assets) external view returns (uint256 shares);

    /**
     * @dev Burns shares from owner and sends exactly assets of underlying tokens to receiver.
     *
     * - MUST emit the Withdraw event.
     * - MAY support an additional flow in which the underlying tokens are owned by the Vault contract before the
     *   withdraw execution, and are accounted for during withdraw.
     * - MUST revert if all of assets cannot be withdrawn (due to withdrawal limit being reached, slippage, the owner
     *   not having enough shares, etc).
     *
     * Note that some implementations will require pre-requesting to the Vault before a withdrawal may be performed.
     * Those methods should be performed separately.
     */
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256 shares);

    /**
     * @dev Returns the maximum amount of Vault shares that can be redeemed from the owner balance in the Vault,
     * through a redeem call.
     *
     * - MUST return a limited value if owner is subject to some withdrawal limit or timelock.
     * - MUST return balanceOf(owner) if owner is not subject to any withdrawal limit or timelock.
     * - MUST NOT revert.
     */
    function maxRedeem(address owner) external view returns (uint256 maxShares);

    /**
     * @dev Allows an on-chain or off-chain user to simulate the effects of their redeemption at the current block,
     * given current on-chain conditions.
     *
     * - MUST return as close to and no more than the exact amount of assets that would be withdrawn in a redeem call
     *   in the same transaction. I.e. redeem should return the same or more assets as previewRedeem if called in the
     *   same transaction.
     * - MUST NOT account for redemption limits like those returned from maxRedeem and should always act as though the
     *   redemption would be accepted, regardless if the user has enough shares, etc.
     * - MUST be inclusive of withdrawal fees. Integrators should be aware of the existence of withdrawal fees.
     * - MUST NOT revert.
     *
     * NOTE: any unfavorable discrepancy between convertToAssets and previewRedeem SHOULD be considered slippage in
     * share price or some other type of condition, meaning the depositor will lose assets by redeeming.
     */
    function previewRedeem(uint256 shares) external view returns (uint256 assets);

    /**
     * @dev Burns exactly shares from owner and sends assets of underlying tokens to receiver.
     *
     * - MUST emit the Withdraw event.
     * - MAY support an additional flow in which the underlying tokens are owned by the Vault contract before the
     *   redeem execution, and are accounted for during redeem.
     * - MUST revert if all of shares cannot be redeemed (due to withdrawal limit being reached, slippage, the owner
     *   not having enough shares, etc).
     *
     * NOTE: some implementations will require pre-requesting to the Vault before a withdrawal may be performed.
     * Those methods should be performed separately.
     */
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets);
}


// File: @openzeppelin/contracts/interfaces/IERC5267.sol

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (interfaces/IERC5267.sol)

pragma solidity ^0.8.20;

interface IERC5267 {
    /**
     * @dev MAY be emitted to signal that the domain could have changed.
     */
    event EIP712DomainChanged();

    /**
     * @dev returns the fields and values that describe the domain separator used by this contract for EIP-712
     * signature.
     */
    function eip712Domain()
        external
        view
        returns (
            bytes1 fields,
            string memory name,
            string memory version,
            uint256 chainId,
            address verifyingContract,
            bytes32 salt,
            uint256[] memory extensions
        );
}


// File: @openzeppelin/contracts/proxy/Proxy.sol

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (proxy/Proxy.sol)

pragma solidity ^0.8.20;

/**
 * @dev This abstract contract provides a fallback function that delegates all calls to another contract using the EVM
 * instruction `delegatecall`. We refer to the second contract as the _implementation_ behind the proxy, and it has to
 * be specified by overriding the virtual {_implementation} function.
 *
 * Additionally, delegation to the implementation can be triggered manually through the {_fallback} function, or to a
 * different contract through the {_delegate} function.
 *
 * The success and return data of the delegated call will be returned back to the caller of the proxy.
 */
abstract contract Proxy {
    /**
     * @dev Delegates the current call to `implementation`.
     *
     * This function does not return to its internal call site, it will return directly to the external caller.
     */
    function _delegate(address implementation) internal virtual {
        assembly {
            // Copy msg.data. We take full control of memory in this inline assembly
            // block because it will not return to Solidity code. We overwrite the
            // Solidity scratch pad at memory position 0.
            calldatacopy(0, 0, calldatasize())

            // Call the implementation.
            // out and outsize are 0 because we don't know the size yet.
            let result := delegatecall(gas(), implementation, 0, calldatasize(), 0, 0)

            // Copy the returned data.
            returndatacopy(0, 0, returndatasize())

            switch result
            // delegatecall returns 0 on error.
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }

    /**
     * @dev This is a virtual function that should be overridden so it returns the address to which the fallback
     * function and {_fallback} should delegate.
     */
    function _implementation() internal view virtual returns (address);

    /**
     * @dev Delegates the current call to the address returned by `_implementation()`.
     *
     * This function does not return to its internal call site, it will return directly to the external caller.
     */
    function _fallback() internal virtual {
        _delegate(_implementation());
    }

    /**
     * @dev Fallback function that delegates calls to the address returned by `_implementation()`. Will run if no other
     * function in the contract matches the call data.
     */
    fallback() external payable virtual {
        _fallback();
    }
}


// File: @openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/extensions/IERC20Metadata.sol)

pragma solidity ^0.8.20;

import {IERC20} from "../IERC20.sol";

/**
 * @dev Interface for the optional metadata functions from the ERC20 standard.
 */
interface IERC20Metadata is IERC20 {
    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() external view returns (uint8);
}


// File: @openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/extensions/IERC20Permit.sol)

pragma solidity ^0.8.20;

/**
 * @dev Interface of the ERC20 Permit extension allowing approvals to be made via signatures, as defined in
 * https://eips.ethereum.org/EIPS/eip-2612[EIP-2612].
 *
 * Adds the {permit} method, which can be used to change an account's ERC20 allowance (see {IERC20-allowance}) by
 * presenting a message signed by the account. By not relying on {IERC20-approve}, the token holder account doesn't
 * need to send a transaction, and thus is not required to hold Ether at all.
 *
 * ==== Security Considerations
 *
 * There are two important considerations concerning the use of `permit`. The first is that a valid permit signature
 * expresses an allowance, and it should not be assumed to convey additional meaning. In particular, it should not be
 * considered as an intention to spend the allowance in any specific way. The second is that because permits have
 * built-in replay protection and can be submitted by anyone, they can be frontrun. A protocol that uses permits should
 * take this into consideration and allow a `permit` call to fail. Combining these two aspects, a pattern that may be
 * generally recommended is:
 *
 * ```solidity
 * function doThingWithPermit(..., uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) public {
 *     try token.permit(msg.sender, address(this), value, deadline, v, r, s) {} catch {}
 *     doThing(..., value);
 * }
 *
 * function doThing(..., uint256 value) public {
 *     token.safeTransferFrom(msg.sender, address(this), value);
 *     ...
 * }
 * ```
 *
 * Observe that: 1) `msg.sender` is used as the owner, leaving no ambiguity as to the signer intent, and 2) the use of
 * `try/catch` allows the permit to fail and makes the code tolerant to frontrunning. (See also
 * {SafeERC20-safeTransferFrom}).
 *
 * Additionally, note that smart contract wallets (such as Argent or Safe) are not able to produce permit signatures, so
 * contracts should have entry points that don't rely on permit.
 */
interface IERC20Permit {
    /**
     * @dev Sets `value` as the allowance of `spender` over ``owner``'s tokens,
     * given ``owner``'s signed approval.
     *
     * IMPORTANT: The same issues {IERC20-approve} has related to transaction
     * ordering also apply here.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `deadline` must be a timestamp in the future.
     * - `v`, `r` and `s` must be a valid `secp256k1` signature from `owner`
     * over the EIP712-formatted function arguments.
     * - the signature must use ``owner``'s current nonce (see {nonces}).
     *
     * For more information on the signature format, see the
     * https://eips.ethereum.org/EIPS/eip-2612#specification[relevant EIP
     * section].
     *
     * CAUTION: See Security Considerations above.
     */
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    /**
     * @dev Returns the current nonce for `owner`. This value must be
     * included whenever a signature is generated for {permit}.
     *
     * Every successful call to {permit} increases ``owner``'s nonce by one. This
     * prevents a signature from being used multiple times.
     */
    function nonces(address owner) external view returns (uint256);

    /**
     * @dev Returns the domain separator used in the encoding of the signature for {permit}, as defined by {EIP712}.
     */
    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}


// File: @openzeppelin/contracts/token/ERC20/IERC20.sol

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.20;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the value of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the value of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 value) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 value) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the
     * allowance mechanism. `value` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}


// File: @openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.20;

import {IERC20} from "../IERC20.sol";
import {IERC20Permit} from "../extensions/IERC20Permit.sol";
import {Address} from "../../../utils/Address.sol";

/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {
    using Address for address;

    /**
     * @dev An operation with an ERC20 token failed.
     */
    error SafeERC20FailedOperation(address token);

    /**
     * @dev Indicates a failed `decreaseAllowance` request.
     */
    error SafeERC20FailedDecreaseAllowance(address spender, uint256 currentAllowance, uint256 requestedDecrease);

    /**
     * @dev Transfer `value` amount of `token` from the calling contract to `to`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeCall(token.transfer, (to, value)));
    }

    /**
     * @dev Transfer `value` amount of `token` from `from` to `to`, spending the approval given by `from` to the
     * calling contract. If `token` returns no value, non-reverting calls are assumed to be successful.
     */
    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeCall(token.transferFrom, (from, to, value)));
    }

    /**
     * @dev Increase the calling contract's allowance toward `spender` by `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 oldAllowance = token.allowance(address(this), spender);
        forceApprove(token, spender, oldAllowance + value);
    }

    /**
     * @dev Decrease the calling contract's allowance toward `spender` by `requestedDecrease`. If `token` returns no
     * value, non-reverting calls are assumed to be successful.
     */
    function safeDecreaseAllowance(IERC20 token, address spender, uint256 requestedDecrease) internal {
        unchecked {
            uint256 currentAllowance = token.allowance(address(this), spender);
            if (currentAllowance < requestedDecrease) {
                revert SafeERC20FailedDecreaseAllowance(spender, currentAllowance, requestedDecrease);
            }
            forceApprove(token, spender, currentAllowance - requestedDecrease);
        }
    }

    /**
     * @dev Set the calling contract's allowance toward `spender` to `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful. Meant to be used with tokens that require the approval
     * to be set to zero before setting it to a non-zero value, such as USDT.
     */
    function forceApprove(IERC20 token, address spender, uint256 value) internal {
        bytes memory approvalCall = abi.encodeCall(token.approve, (spender, value));

        if (!_callOptionalReturnBool(token, approvalCall)) {
            _callOptionalReturn(token, abi.encodeCall(token.approve, (spender, 0)));
            _callOptionalReturn(token, approvalCall);
        }
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address-functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data);
        if (returndata.length != 0 && !abi.decode(returndata, (bool))) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     *
     * This is a variant of {_callOptionalReturn} that silents catches all reverts and returns a bool instead.
     */
    function _callOptionalReturnBool(IERC20 token, bytes memory data) private returns (bool) {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We cannot use {Address-functionCall} here since this should return false
        // and not revert is the subcall reverts.

        (bool success, bytes memory returndata) = address(token).call(data);
        return success && (returndata.length == 0 || abi.decode(returndata, (bool))) && address(token).code.length > 0;
    }
}


// File: @openzeppelin/contracts/utils/Address.sol

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (utils/Address.sol)

pragma solidity ^0.8.20;

/**
 * @dev Collection of functions related to the address type
 */
library Address {
    /**
     * @dev The ETH balance of the account is not enough to perform the operation.
     */
    error AddressInsufficientBalance(address account);

    /**
     * @dev There's no code at `target` (it is not a contract).
     */
    error AddressEmptyCode(address target);

    /**
     * @dev A call to an address target failed. The target may have reverted.
     */
    error FailedInnerCall();

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://consensys.net/diligence/blog/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.8.20/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        if (address(this).balance < amount) {
            revert AddressInsufficientBalance(address(this));
        }

        (bool success, ) = recipient.call{value: amount}("");
        if (!success) {
            revert FailedInnerCall();
        }
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason or custom error, it is bubbled
     * up by this function (like regular Solidity function calls). However, if
     * the call reverted with no returned reason, this function reverts with a
     * {FailedInnerCall} error.
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        if (address(this).balance < value) {
            revert AddressInsufficientBalance(address(this));
        }
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResultFromTarget(target, success, returndata);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResultFromTarget(target, success, returndata);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResultFromTarget(target, success, returndata);
    }

    /**
     * @dev Tool to verify that a low level call to smart-contract was successful, and reverts if the target
     * was not a contract or bubbling up the revert reason (falling back to {FailedInnerCall}) in case of an
     * unsuccessful call.
     */
    function verifyCallResultFromTarget(
        address target,
        bool success,
        bytes memory returndata
    ) internal view returns (bytes memory) {
        if (!success) {
            _revert(returndata);
        } else {
            // only check if target is a contract if the call was successful and the return data is empty
            // otherwise we already know that it was a contract
            if (returndata.length == 0 && target.code.length == 0) {
                revert AddressEmptyCode(target);
            }
            return returndata;
        }
    }

    /**
     * @dev Tool to verify that a low level call was successful, and reverts if it wasn't, either by bubbling the
     * revert reason or with a default {FailedInnerCall} error.
     */
    function verifyCallResult(bool success, bytes memory returndata) internal pure returns (bytes memory) {
        if (!success) {
            _revert(returndata);
        } else {
            return returndata;
        }
    }

    /**
     * @dev Reverts with returndata if present. Otherwise reverts with {FailedInnerCall}.
     */
    function _revert(bytes memory returndata) private pure {
        // Look for revert reason and bubble it up if present
        if (returndata.length > 0) {
            // The easiest way to bubble the revert reason is using memory via assembly
            /// @solidity memory-safe-assembly
            assembly {
                let returndata_size := mload(returndata)
                revert(add(32, returndata), returndata_size)
            }
        } else {
            revert FailedInnerCall();
        }
    }
}


// File: @openzeppelin/contracts/utils/cryptography/ECDSA.sol

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (utils/cryptography/ECDSA.sol)

pragma solidity ^0.8.20;

/**
 * @dev Elliptic Curve Digital Signature Algorithm (ECDSA) operations.
 *
 * These functions can be used to verify that a message was signed by the holder
 * of the private keys of a given address.
 */
library ECDSA {
    enum RecoverError {
        NoError,
        InvalidSignature,
        InvalidSignatureLength,
        InvalidSignatureS
    }

    /**
     * @dev The signature derives the `address(0)`.
     */
    error ECDSAInvalidSignature();

    /**
     * @dev The signature has an invalid length.
     */
    error ECDSAInvalidSignatureLength(uint256 length);

    /**
     * @dev The signature has an S value that is in the upper half order.
     */
    error ECDSAInvalidSignatureS(bytes32 s);

    /**
     * @dev Returns the address that signed a hashed message (`hash`) with `signature` or an error. This will not
     * return address(0) without also returning an error description. Errors are documented using an enum (error type)
     * and a bytes32 providing additional information about the error.
     *
     * If no error is returned, then the address can be used for verification purposes.
     *
     * The `ecrecover` EVM precompile allows for malleable (non-unique) signatures:
     * this function rejects them by requiring the `s` value to be in the lower
     * half order, and the `v` value to be either 27 or 28.
     *
     * IMPORTANT: `hash` _must_ be the result of a hash operation for the
     * verification to be secure: it is possible to craft signatures that
     * recover to arbitrary addresses for non-hashed data. A safe way to ensure
     * this is by receiving a hash of the original message (which may otherwise
     * be too long), and then calling {MessageHashUtils-toEthSignedMessageHash} on it.
     *
     * Documentation for signature generation:
     * - with https://web3js.readthedocs.io/en/v1.3.4/web3-eth-accounts.html#sign[Web3.js]
     * - with https://docs.ethers.io/v5/api/signer/#Signer-signMessage[ethers]
     */
    function tryRecover(bytes32 hash, bytes memory signature) internal pure returns (address, RecoverError, bytes32) {
        if (signature.length == 65) {
            bytes32 r;
            bytes32 s;
            uint8 v;
            // ecrecover takes the signature parameters, and the only way to get them
            // currently is to use assembly.
            /// @solidity memory-safe-assembly
            assembly {
                r := mload(add(signature, 0x20))
                s := mload(add(signature, 0x40))
                v := byte(0, mload(add(signature, 0x60)))
            }
            return tryRecover(hash, v, r, s);
        } else {
            return (address(0), RecoverError.InvalidSignatureLength, bytes32(signature.length));
        }
    }

    /**
     * @dev Returns the address that signed a hashed message (`hash`) with
     * `signature`. This address can then be used for verification purposes.
     *
     * The `ecrecover` EVM precompile allows for malleable (non-unique) signatures:
     * this function rejects them by requiring the `s` value to be in the lower
     * half order, and the `v` value to be either 27 or 28.
     *
     * IMPORTANT: `hash` _must_ be the result of a hash operation for the
     * verification to be secure: it is possible to craft signatures that
     * recover to arbitrary addresses for non-hashed data. A safe way to ensure
     * this is by receiving a hash of the original message (which may otherwise
     * be too long), and then calling {MessageHashUtils-toEthSignedMessageHash} on it.
     */
    function recover(bytes32 hash, bytes memory signature) internal pure returns (address) {
        (address recovered, RecoverError error, bytes32 errorArg) = tryRecover(hash, signature);
        _throwError(error, errorArg);
        return recovered;
    }

    /**
     * @dev Overload of {ECDSA-tryRecover} that receives the `r` and `vs` short-signature fields separately.
     *
     * See https://eips.ethereum.org/EIPS/eip-2098[EIP-2098 short signatures]
     */
    function tryRecover(bytes32 hash, bytes32 r, bytes32 vs) internal pure returns (address, RecoverError, bytes32) {
        unchecked {
            bytes32 s = vs & bytes32(0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
            // We do not check for an overflow here since the shift operation results in 0 or 1.
            uint8 v = uint8((uint256(vs) >> 255) + 27);
            return tryRecover(hash, v, r, s);
        }
    }

    /**
     * @dev Overload of {ECDSA-recover} that receives the `r and `vs` short-signature fields separately.
     */
    function recover(bytes32 hash, bytes32 r, bytes32 vs) internal pure returns (address) {
        (address recovered, RecoverError error, bytes32 errorArg) = tryRecover(hash, r, vs);
        _throwError(error, errorArg);
        return recovered;
    }

    /**
     * @dev Overload of {ECDSA-tryRecover} that receives the `v`,
     * `r` and `s` signature fields separately.
     */
    function tryRecover(
        bytes32 hash,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal pure returns (address, RecoverError, bytes32) {
        // EIP-2 still allows signature malleability for ecrecover(). Remove this possibility and make the signature
        // unique. Appendix F in the Ethereum Yellow paper (https://ethereum.github.io/yellowpaper/paper.pdf), defines
        // the valid range for s in (301): 0 < s < secp256k1n ÷ 2 + 1, and for v in (302): v ∈ {27, 28}. Most
        // signatures from current libraries generate a unique signature with an s-value in the lower half order.
        //
        // If your library generates malleable signatures, such as s-values in the upper range, calculate a new s-value
        // with 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141 - s1 and flip v from 27 to 28 or
        // vice versa. If your library also generates signatures with 0/1 for v instead 27/28, add 27 to v to accept
        // these malleable signatures as well.
        if (uint256(s) > 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0) {
            return (address(0), RecoverError.InvalidSignatureS, s);
        }

        // If the signature is valid (and not malleable), return the signer address
        address signer = ecrecover(hash, v, r, s);
        if (signer == address(0)) {
            return (address(0), RecoverError.InvalidSignature, bytes32(0));
        }

        return (signer, RecoverError.NoError, bytes32(0));
    }

    /**
     * @dev Overload of {ECDSA-recover} that receives the `v`,
     * `r` and `s` signature fields separately.
     */
    function recover(bytes32 hash, uint8 v, bytes32 r, bytes32 s) internal pure returns (address) {
        (address recovered, RecoverError error, bytes32 errorArg) = tryRecover(hash, v, r, s);
        _throwError(error, errorArg);
        return recovered;
    }

    /**
     * @dev Optionally reverts with the corresponding custom error according to the `error` argument provided.
     */
    function _throwError(RecoverError error, bytes32 errorArg) private pure {
        if (error == RecoverError.NoError) {
            return; // no error: do nothing
        } else if (error == RecoverError.InvalidSignature) {
            revert ECDSAInvalidSignature();
        } else if (error == RecoverError.InvalidSignatureLength) {
            revert ECDSAInvalidSignatureLength(uint256(errorArg));
        } else if (error == RecoverError.InvalidSignatureS) {
            revert ECDSAInvalidSignatureS(errorArg);
        }
    }
}


// File: @openzeppelin/contracts/utils/cryptography/EIP712.sol

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (utils/cryptography/EIP712.sol)

pragma solidity ^0.8.20;

import {MessageHashUtils} from "./MessageHashUtils.sol";
import {ShortStrings, ShortString} from "../ShortStrings.sol";
import {IERC5267} from "../../interfaces/IERC5267.sol";

/**
 * @dev https://eips.ethereum.org/EIPS/eip-712[EIP 712] is a standard for hashing and signing of typed structured data.
 *
 * The encoding scheme specified in the EIP requires a domain separator and a hash of the typed structured data, whose
 * encoding is very generic and therefore its implementation in Solidity is not feasible, thus this contract
 * does not implement the encoding itself. Protocols need to implement the type-specific encoding they need in order to
 * produce the hash of their typed data using a combination of `abi.encode` and `keccak256`.
 *
 * This contract implements the EIP 712 domain separator ({_domainSeparatorV4}) that is used as part of the encoding
 * scheme, and the final step of the encoding to obtain the message digest that is then signed via ECDSA
 * ({_hashTypedDataV4}).
 *
 * The implementation of the domain separator was designed to be as efficient as possible while still properly updating
 * the chain id to protect against replay attacks on an eventual fork of the chain.
 *
 * NOTE: This contract implements the version of the encoding known as "v4", as implemented by the JSON RPC method
 * https://docs.metamask.io/guide/signing-data.html[`eth_signTypedDataV4` in MetaMask].
 *
 * NOTE: In the upgradeable version of this contract, the cached values will correspond to the address, and the domain
 * separator of the implementation contract. This will cause the {_domainSeparatorV4} function to always rebuild the
 * separator from the immutable values, which is cheaper than accessing a cached version in cold storage.
 *
 * @custom:oz-upgrades-unsafe-allow state-variable-immutable
 */
abstract contract EIP712 is IERC5267 {
    using ShortStrings for *;

    bytes32 private constant TYPE_HASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

    // Cache the domain separator as an immutable value, but also store the chain id that it corresponds to, in order to
    // invalidate the cached domain separator if the chain id changes.
    bytes32 private immutable _cachedDomainSeparator;
    uint256 private immutable _cachedChainId;
    address private immutable _cachedThis;

    bytes32 private immutable _hashedName;
    bytes32 private immutable _hashedVersion;

    ShortString private immutable _name;
    ShortString private immutable _version;
    string private _nameFallback;
    string private _versionFallback;

    /**
     * @dev Initializes the domain separator and parameter caches.
     *
     * The meaning of `name` and `version` is specified in
     * https://eips.ethereum.org/EIPS/eip-712#definition-of-domainseparator[EIP 712]:
     *
     * - `name`: the user readable name of the signing domain, i.e. the name of the DApp or the protocol.
     * - `version`: the current major version of the signing domain.
     *
     * NOTE: These parameters cannot be changed except through a xref:learn::upgrading-smart-contracts.adoc[smart
     * contract upgrade].
     */
    constructor(string memory name, string memory version) {
        _name = name.toShortStringWithFallback(_nameFallback);
        _version = version.toShortStringWithFallback(_versionFallback);
        _hashedName = keccak256(bytes(name));
        _hashedVersion = keccak256(bytes(version));

        _cachedChainId = block.chainid;
        _cachedDomainSeparator = _buildDomainSeparator();
        _cachedThis = address(this);
    }

    /**
     * @dev Returns the domain separator for the current chain.
     */
    function _domainSeparatorV4() internal view returns (bytes32) {
        if (address(this) == _cachedThis && block.chainid == _cachedChainId) {
            return _cachedDomainSeparator;
        } else {
            return _buildDomainSeparator();
        }
    }

    function _buildDomainSeparator() private view returns (bytes32) {
        return keccak256(abi.encode(TYPE_HASH, _hashedName, _hashedVersion, block.chainid, address(this)));
    }

    /**
     * @dev Given an already https://eips.ethereum.org/EIPS/eip-712#definition-of-hashstruct[hashed struct], this
     * function returns the hash of the fully encoded EIP712 message for this domain.
     *
     * This hash can be used together with {ECDSA-recover} to obtain the signer of a message. For example:
     *
     * ```solidity
     * bytes32 digest = _hashTypedDataV4(keccak256(abi.encode(
     *     keccak256("Mail(address to,string contents)"),
     *     mailTo,
     *     keccak256(bytes(mailContents))
     * )));
     * address signer = ECDSA.recover(digest, signature);
     * ```
     */
    function _hashTypedDataV4(bytes32 structHash) internal view virtual returns (bytes32) {
        return MessageHashUtils.toTypedDataHash(_domainSeparatorV4(), structHash);
    }

    /**
     * @dev See {IERC-5267}.
     */
    function eip712Domain()
        public
        view
        virtual
        returns (
            bytes1 fields,
            string memory name,
            string memory version,
            uint256 chainId,
            address verifyingContract,
            bytes32 salt,
            uint256[] memory extensions
        )
    {
        return (
            hex"0f", // 01111
            _EIP712Name(),
            _EIP712Version(),
            block.chainid,
            address(this),
            bytes32(0),
            new uint256[](0)
        );
    }

    /**
     * @dev The name parameter for the EIP712 domain.
     *
     * NOTE: By default this function reads _name which is an immutable value.
     * It only reads from storage if necessary (in case the value is too large to fit in a ShortString).
     */
    // solhint-disable-next-line func-name-mixedcase
    function _EIP712Name() internal view returns (string memory) {
        return _name.toStringWithFallback(_nameFallback);
    }

    /**
     * @dev The version parameter for the EIP712 domain.
     *
     * NOTE: By default this function reads _version which is an immutable value.
     * It only reads from storage if necessary (in case the value is too large to fit in a ShortString).
     */
    // solhint-disable-next-line func-name-mixedcase
    function _EIP712Version() internal view returns (string memory) {
        return _version.toStringWithFallback(_versionFallback);
    }
}


// File: @openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (utils/cryptography/MessageHashUtils.sol)

pragma solidity ^0.8.20;

import {Strings} from "../Strings.sol";

/**
 * @dev Signature message hash utilities for producing digests to be consumed by {ECDSA} recovery or signing.
 *
 * The library provides methods for generating a hash of a message that conforms to the
 * https://eips.ethereum.org/EIPS/eip-191[EIP 191] and https://eips.ethereum.org/EIPS/eip-712[EIP 712]
 * specifications.
 */
library MessageHashUtils {
    /**
     * @dev Returns the keccak256 digest of an EIP-191 signed data with version
     * `0x45` (`personal_sign` messages).
     *
     * The digest is calculated by prefixing a bytes32 `messageHash` with
     * `"\x19Ethereum Signed Message:\n32"` and hashing the result. It corresponds with the
     * hash signed when using the https://eth.wiki/json-rpc/API#eth_sign[`eth_sign`] JSON-RPC method.
     *
     * NOTE: The `messageHash` parameter is intended to be the result of hashing a raw message with
     * keccak256, although any bytes32 value can be safely used because the final digest will
     * be re-hashed.
     *
     * See {ECDSA-recover}.
     */
    function toEthSignedMessageHash(bytes32 messageHash) internal pure returns (bytes32 digest) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, "\x19Ethereum Signed Message:\n32") // 32 is the bytes-length of messageHash
            mstore(0x1c, messageHash) // 0x1c (28) is the length of the prefix
            digest := keccak256(0x00, 0x3c) // 0x3c is the length of the prefix (0x1c) + messageHash (0x20)
        }
    }

    /**
     * @dev Returns the keccak256 digest of an EIP-191 signed data with version
     * `0x45` (`personal_sign` messages).
     *
     * The digest is calculated by prefixing an arbitrary `message` with
     * `"\x19Ethereum Signed Message:\n" + len(message)` and hashing the result. It corresponds with the
     * hash signed when using the https://eth.wiki/json-rpc/API#eth_sign[`eth_sign`] JSON-RPC method.
     *
     * See {ECDSA-recover}.
     */
    function toEthSignedMessageHash(bytes memory message) internal pure returns (bytes32) {
        return
            keccak256(bytes.concat("\x19Ethereum Signed Message:\n", bytes(Strings.toString(message.length)), message));
    }

    /**
     * @dev Returns the keccak256 digest of an EIP-191 signed data with version
     * `0x00` (data with intended validator).
     *
     * The digest is calculated by prefixing an arbitrary `data` with `"\x19\x00"` and the intended
     * `validator` address. Then hashing the result.
     *
     * See {ECDSA-recover}.
     */
    function toDataWithIntendedValidatorHash(address validator, bytes memory data) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(hex"19_00", validator, data));
    }

    /**
     * @dev Returns the keccak256 digest of an EIP-712 typed data (EIP-191 version `0x01`).
     *
     * The digest is calculated from a `domainSeparator` and a `structHash`, by prefixing them with
     * `\x19\x01` and hashing the result. It corresponds to the hash signed by the
     * https://eips.ethereum.org/EIPS/eip-712[`eth_signTypedData`] JSON-RPC method as part of EIP-712.
     *
     * See {ECDSA-recover}.
     */
    function toTypedDataHash(bytes32 domainSeparator, bytes32 structHash) internal pure returns (bytes32 digest) {
        /// @solidity memory-safe-assembly
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, hex"19_01")
            mstore(add(ptr, 0x02), domainSeparator)
            mstore(add(ptr, 0x22), structHash)
            digest := keccak256(ptr, 0x42)
        }
    }
}


// File: @openzeppelin/contracts/utils/introspection/ERC165.sol

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (utils/introspection/ERC165.sol)

pragma solidity ^0.8.20;

import {IERC165} from "./IERC165.sol";

/**
 * @dev Implementation of the {IERC165} interface.
 *
 * Contracts that want to implement ERC165 should inherit from this contract and override {supportsInterface} to check
 * for the additional interface id that will be supported. For example:
 *
 * ```solidity
 * function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
 *     return interfaceId == type(MyInterface).interfaceId || super.supportsInterface(interfaceId);
 * }
 * ```
 */
abstract contract ERC165 is IERC165 {
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return interfaceId == type(IERC165).interfaceId;
    }
}


// File: @openzeppelin/contracts/utils/introspection/IERC165.sol

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (utils/introspection/IERC165.sol)

pragma solidity ^0.8.20;

/**
 * @dev Interface of the ERC165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[EIP].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165 {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}


// File: @openzeppelin/contracts/utils/math/Math.sol

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (utils/math/Math.sol)

pragma solidity ^0.8.20;

/**
 * @dev Standard math utilities missing in the Solidity language.
 */
library Math {
    /**
     * @dev Muldiv operation overflow.
     */
    error MathOverflowedMulDiv();

    enum Rounding {
        Floor, // Toward negative infinity
        Ceil, // Toward positive infinity
        Trunc, // Toward zero
        Expand // Away from zero
    }

    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            uint256 c = a + b;
            if (c < a) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, with an overflow flag.
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b > a) return (false, 0);
            return (true, a - b);
        }
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
            // benefit is lost if 'b' is also tested.
            // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
            if (a == 0) return (true, 0);
            uint256 c = a * b;
            if (c / a != b) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a / b);
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a % b);
        }
    }

    /**
     * @dev Returns the largest of two numbers.
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }

    /**
     * @dev Returns the smallest of two numbers.
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /**
     * @dev Returns the average of two numbers. The result is rounded towards
     * zero.
     */
    function average(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b) / 2 can overflow.
        return (a & b) + (a ^ b) / 2;
    }

    /**
     * @dev Returns the ceiling of the division of two numbers.
     *
     * This differs from standard division with `/` in that it rounds towards infinity instead
     * of rounding towards zero.
     */
    function ceilDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        if (b == 0) {
            // Guarantee the same behavior as in a regular Solidity division.
            return a / b;
        }

        // (a + b - 1) / b can overflow on addition, so we distribute.
        return a == 0 ? 0 : (a - 1) / b + 1;
    }

    /**
     * @notice Calculates floor(x * y / denominator) with full precision. Throws if result overflows a uint256 or
     * denominator == 0.
     * @dev Original credit to Remco Bloemen under MIT license (https://xn--2-umb.com/21/muldiv) with further edits by
     * Uniswap Labs also under MIT license.
     */
    function mulDiv(uint256 x, uint256 y, uint256 denominator) internal pure returns (uint256 result) {
        unchecked {
            // 512-bit multiply [prod1 prod0] = x * y. Compute the product mod 2^256 and mod 2^256 - 1, then use
            // use the Chinese Remainder Theorem to reconstruct the 512 bit result. The result is stored in two 256
            // variables such that product = prod1 * 2^256 + prod0.
            uint256 prod0 = x * y; // Least significant 256 bits of the product
            uint256 prod1; // Most significant 256 bits of the product
            assembly {
                let mm := mulmod(x, y, not(0))
                prod1 := sub(sub(mm, prod0), lt(mm, prod0))
            }

            // Handle non-overflow cases, 256 by 256 division.
            if (prod1 == 0) {
                // Solidity will revert if denominator == 0, unlike the div opcode on its own.
                // The surrounding unchecked block does not change this fact.
                // See https://docs.soliditylang.org/en/latest/control-structures.html#checked-or-unchecked-arithmetic.
                return prod0 / denominator;
            }

            // Make sure the result is less than 2^256. Also prevents denominator == 0.
            if (denominator <= prod1) {
                revert MathOverflowedMulDiv();
            }

            ///////////////////////////////////////////////
            // 512 by 256 division.
            ///////////////////////////////////////////////

            // Make division exact by subtracting the remainder from [prod1 prod0].
            uint256 remainder;
            assembly {
                // Compute remainder using mulmod.
                remainder := mulmod(x, y, denominator)

                // Subtract 256 bit number from 512 bit number.
                prod1 := sub(prod1, gt(remainder, prod0))
                prod0 := sub(prod0, remainder)
            }

            // Factor powers of two out of denominator and compute largest power of two divisor of denominator.
            // Always >= 1. See https://cs.stackexchange.com/q/138556/92363.

            uint256 twos = denominator & (0 - denominator);
            assembly {
                // Divide denominator by twos.
                denominator := div(denominator, twos)

                // Divide [prod1 prod0] by twos.
                prod0 := div(prod0, twos)

                // Flip twos such that it is 2^256 / twos. If twos is zero, then it becomes one.
                twos := add(div(sub(0, twos), twos), 1)
            }

            // Shift in bits from prod1 into prod0.
            prod0 |= prod1 * twos;

            // Invert denominator mod 2^256. Now that denominator is an odd number, it has an inverse modulo 2^256 such
            // that denominator * inv = 1 mod 2^256. Compute the inverse by starting with a seed that is correct for
            // four bits. That is, denominator * inv = 1 mod 2^4.
            uint256 inverse = (3 * denominator) ^ 2;

            // Use the Newton-Raphson iteration to improve the precision. Thanks to Hensel's lifting lemma, this also
            // works in modular arithmetic, doubling the correct bits in each step.
            inverse *= 2 - denominator * inverse; // inverse mod 2^8
            inverse *= 2 - denominator * inverse; // inverse mod 2^16
            inverse *= 2 - denominator * inverse; // inverse mod 2^32
            inverse *= 2 - denominator * inverse; // inverse mod 2^64
            inverse *= 2 - denominator * inverse; // inverse mod 2^128
            inverse *= 2 - denominator * inverse; // inverse mod 2^256

            // Because the division is now exact we can divide by multiplying with the modular inverse of denominator.
            // This will give us the correct result modulo 2^256. Since the preconditions guarantee that the outcome is
            // less than 2^256, this is the final result. We don't need to compute the high bits of the result and prod1
            // is no longer required.
            result = prod0 * inverse;
            return result;
        }
    }

    /**
     * @notice Calculates x * y / denominator with full precision, following the selected rounding direction.
     */
    function mulDiv(uint256 x, uint256 y, uint256 denominator, Rounding rounding) internal pure returns (uint256) {
        uint256 result = mulDiv(x, y, denominator);
        if (unsignedRoundsUp(rounding) && mulmod(x, y, denominator) > 0) {
            result += 1;
        }
        return result;
    }

    /**
     * @dev Returns the square root of a number. If the number is not a perfect square, the value is rounded
     * towards zero.
     *
     * Inspired by Henry S. Warren, Jr.'s "Hacker's Delight" (Chapter 11).
     */
    function sqrt(uint256 a) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        // For our first guess, we get the biggest power of 2 which is smaller than the square root of the target.
        //
        // We know that the "msb" (most significant bit) of our target number `a` is a power of 2 such that we have
        // `msb(a) <= a < 2*msb(a)`. This value can be written `msb(a)=2**k` with `k=log2(a)`.
        //
        // This can be rewritten `2**log2(a) <= a < 2**(log2(a) + 1)`
        // → `sqrt(2**k) <= sqrt(a) < sqrt(2**(k+1))`
        // → `2**(k/2) <= sqrt(a) < 2**((k+1)/2) <= 2**(k/2 + 1)`
        //
        // Consequently, `2**(log2(a) / 2)` is a good first approximation of `sqrt(a)` with at least 1 correct bit.
        uint256 result = 1 << (log2(a) >> 1);

        // At this point `result` is an estimation with one bit of precision. We know the true value is a uint128,
        // since it is the square root of a uint256. Newton's method converges quadratically (precision doubles at
        // every iteration). We thus need at most 7 iteration to turn our partial result with one bit of precision
        // into the expected uint128 result.
        unchecked {
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            return min(result, a / result);
        }
    }

    /**
     * @notice Calculates sqrt(a), following the selected rounding direction.
     */
    function sqrt(uint256 a, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = sqrt(a);
            return result + (unsignedRoundsUp(rounding) && result * result < a ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 2 of a positive value rounded towards zero.
     * Returns 0 if given 0.
     */
    function log2(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >> 128 > 0) {
                value >>= 128;
                result += 128;
            }
            if (value >> 64 > 0) {
                value >>= 64;
                result += 64;
            }
            if (value >> 32 > 0) {
                value >>= 32;
                result += 32;
            }
            if (value >> 16 > 0) {
                value >>= 16;
                result += 16;
            }
            if (value >> 8 > 0) {
                value >>= 8;
                result += 8;
            }
            if (value >> 4 > 0) {
                value >>= 4;
                result += 4;
            }
            if (value >> 2 > 0) {
                value >>= 2;
                result += 2;
            }
            if (value >> 1 > 0) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 2, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log2(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log2(value);
            return result + (unsignedRoundsUp(rounding) && 1 << result < value ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 10 of a positive value rounded towards zero.
     * Returns 0 if given 0.
     */
    function log10(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >= 10 ** 64) {
                value /= 10 ** 64;
                result += 64;
            }
            if (value >= 10 ** 32) {
                value /= 10 ** 32;
                result += 32;
            }
            if (value >= 10 ** 16) {
                value /= 10 ** 16;
                result += 16;
            }
            if (value >= 10 ** 8) {
                value /= 10 ** 8;
                result += 8;
            }
            if (value >= 10 ** 4) {
                value /= 10 ** 4;
                result += 4;
            }
            if (value >= 10 ** 2) {
                value /= 10 ** 2;
                result += 2;
            }
            if (value >= 10 ** 1) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 10, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log10(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log10(value);
            return result + (unsignedRoundsUp(rounding) && 10 ** result < value ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 256 of a positive value rounded towards zero.
     * Returns 0 if given 0.
     *
     * Adding one to the result gives the number of pairs of hex symbols needed to represent `value` as a hex string.
     */
    function log256(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >> 128 > 0) {
                value >>= 128;
                result += 16;
            }
            if (value >> 64 > 0) {
                value >>= 64;
                result += 8;
            }
            if (value >> 32 > 0) {
                value >>= 32;
                result += 4;
            }
            if (value >> 16 > 0) {
                value >>= 16;
                result += 2;
            }
            if (value >> 8 > 0) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 256, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log256(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log256(value);
            return result + (unsignedRoundsUp(rounding) && 1 << (result << 3) < value ? 1 : 0);
        }
    }

    /**
     * @dev Returns whether a provided rounding mode is considered rounding up for unsigned integers.
     */
    function unsignedRoundsUp(Rounding rounding) internal pure returns (bool) {
        return uint8(rounding) % 2 == 1;
    }
}


// File: @openzeppelin/contracts/utils/math/SafeCast.sol

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (utils/math/SafeCast.sol)
// This file was procedurally generated from scripts/generate/templates/SafeCast.js.

pragma solidity ^0.8.20;

/**
 * @dev Wrappers over Solidity's uintXX/intXX casting operators with added overflow
 * checks.
 *
 * Downcasting from uint256/int256 in Solidity does not revert on overflow. This can
 * easily result in undesired exploitation or bugs, since developers usually
 * assume that overflows raise errors. `SafeCast` restores this intuition by
 * reverting the transaction when such an operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 */
library SafeCast {
    /**
     * @dev Value doesn't fit in an uint of `bits` size.
     */
    error SafeCastOverflowedUintDowncast(uint8 bits, uint256 value);

    /**
     * @dev An int value doesn't fit in an uint of `bits` size.
     */
    error SafeCastOverflowedIntToUint(int256 value);

    /**
     * @dev Value doesn't fit in an int of `bits` size.
     */
    error SafeCastOverflowedIntDowncast(uint8 bits, int256 value);

    /**
     * @dev An uint value doesn't fit in an int of `bits` size.
     */
    error SafeCastOverflowedUintToInt(uint256 value);

    /**
     * @dev Returns the downcasted uint248 from uint256, reverting on
     * overflow (when the input is greater than largest uint248).
     *
     * Counterpart to Solidity's `uint248` operator.
     *
     * Requirements:
     *
     * - input must fit into 248 bits
     */
    function toUint248(uint256 value) internal pure returns (uint248) {
        if (value > type(uint248).max) {
            revert SafeCastOverflowedUintDowncast(248, value);
        }
        return uint248(value);
    }

    /**
     * @dev Returns the downcasted uint240 from uint256, reverting on
     * overflow (when the input is greater than largest uint240).
     *
     * Counterpart to Solidity's `uint240` operator.
     *
     * Requirements:
     *
     * - input must fit into 240 bits
     */
    function toUint240(uint256 value) internal pure returns (uint240) {
        if (value > type(uint240).max) {
            revert SafeCastOverflowedUintDowncast(240, value);
        }
        return uint240(value);
    }

    /**
     * @dev Returns the downcasted uint232 from uint256, reverting on
     * overflow (when the input is greater than largest uint232).
     *
     * Counterpart to Solidity's `uint232` operator.
     *
     * Requirements:
     *
     * - input must fit into 232 bits
     */
    function toUint232(uint256 value) internal pure returns (uint232) {
        if (value > type(uint232).max) {
            revert SafeCastOverflowedUintDowncast(232, value);
        }
        return uint232(value);
    }

    /**
     * @dev Returns the downcasted uint224 from uint256, reverting on
     * overflow (when the input is greater than largest uint224).
     *
     * Counterpart to Solidity's `uint224` operator.
     *
     * Requirements:
     *
     * - input must fit into 224 bits
     */
    function toUint224(uint256 value) internal pure returns (uint224) {
        if (value > type(uint224).max) {
            revert SafeCastOverflowedUintDowncast(224, value);
        }
        return uint224(value);
    }

    /**
     * @dev Returns the downcasted uint216 from uint256, reverting on
     * overflow (when the input is greater than largest uint216).
     *
     * Counterpart to Solidity's `uint216` operator.
     *
     * Requirements:
     *
     * - input must fit into 216 bits
     */
    function toUint216(uint256 value) internal pure returns (uint216) {
        if (value > type(uint216).max) {
            revert SafeCastOverflowedUintDowncast(216, value);
        }
        return uint216(value);
    }

    /**
     * @dev Returns the downcasted uint208 from uint256, reverting on
     * overflow (when the input is greater than largest uint208).
     *
     * Counterpart to Solidity's `uint208` operator.
     *
     * Requirements:
     *
     * - input must fit into 208 bits
     */
    function toUint208(uint256 value) internal pure returns (uint208) {
        if (value > type(uint208).max) {
            revert SafeCastOverflowedUintDowncast(208, value);
        }
        return uint208(value);
    }

    /**
     * @dev Returns the downcasted uint200 from uint256, reverting on
     * overflow (when the input is greater than largest uint200).
     *
     * Counterpart to Solidity's `uint200` operator.
     *
     * Requirements:
     *
     * - input must fit into 200 bits
     */
    function toUint200(uint256 value) internal pure returns (uint200) {
        if (value > type(uint200).max) {
            revert SafeCastOverflowedUintDowncast(200, value);
        }
        return uint200(value);
    }

    /**
     * @dev Returns the downcasted uint192 from uint256, reverting on
     * overflow (when the input is greater than largest uint192).
     *
     * Counterpart to Solidity's `uint192` operator.
     *
     * Requirements:
     *
     * - input must fit into 192 bits
     */
    function toUint192(uint256 value) internal pure returns (uint192) {
        if (value > type(uint192).max) {
            revert SafeCastOverflowedUintDowncast(192, value);
        }
        return uint192(value);
    }

    /**
     * @dev Returns the downcasted uint184 from uint256, reverting on
     * overflow (when the input is greater than largest uint184).
     *
     * Counterpart to Solidity's `uint184` operator.
     *
     * Requirements:
     *
     * - input must fit into 184 bits
     */
    function toUint184(uint256 value) internal pure returns (uint184) {
        if (value > type(uint184).max) {
            revert SafeCastOverflowedUintDowncast(184, value);
        }
        return uint184(value);
    }

    /**
     * @dev Returns the downcasted uint176 from uint256, reverting on
     * overflow (when the input is greater than largest uint176).
     *
     * Counterpart to Solidity's `uint176` operator.
     *
     * Requirements:
     *
     * - input must fit into 176 bits
     */
    function toUint176(uint256 value) internal pure returns (uint176) {
        if (value > type(uint176).max) {
            revert SafeCastOverflowedUintDowncast(176, value);
        }
        return uint176(value);
    }

    /**
     * @dev Returns the downcasted uint168 from uint256, reverting on
     * overflow (when the input is greater than largest uint168).
     *
     * Counterpart to Solidity's `uint168` operator.
     *
     * Requirements:
     *
     * - input must fit into 168 bits
     */
    function toUint168(uint256 value) internal pure returns (uint168) {
        if (value > type(uint168).max) {
            revert SafeCastOverflowedUintDowncast(168, value);
        }
        return uint168(value);
    }

    /**
     * @dev Returns the downcasted uint160 from uint256, reverting on
     * overflow (when the input is greater than largest uint160).
     *
     * Counterpart to Solidity's `uint160` operator.
     *
     * Requirements:
     *
     * - input must fit into 160 bits
     */
    function toUint160(uint256 value) internal pure returns (uint160) {
        if (value > type(uint160).max) {
            revert SafeCastOverflowedUintDowncast(160, value);
        }
        return uint160(value);
    }

    /**
     * @dev Returns the downcasted uint152 from uint256, reverting on
     * overflow (when the input is greater than largest uint152).
     *
     * Counterpart to Solidity's `uint152` operator.
     *
     * Requirements:
     *
     * - input must fit into 152 bits
     */
    function toUint152(uint256 value) internal pure returns (uint152) {
        if (value > type(uint152).max) {
            revert SafeCastOverflowedUintDowncast(152, value);
        }
        return uint152(value);
    }

    /**
     * @dev Returns the downcasted uint144 from uint256, reverting on
     * overflow (when the input is greater than largest uint144).
     *
     * Counterpart to Solidity's `uint144` operator.
     *
     * Requirements:
     *
     * - input must fit into 144 bits
     */
    function toUint144(uint256 value) internal pure returns (uint144) {
        if (value > type(uint144).max) {
            revert SafeCastOverflowedUintDowncast(144, value);
        }
        return uint144(value);
    }

    /**
     * @dev Returns the downcasted uint136 from uint256, reverting on
     * overflow (when the input is greater than largest uint136).
     *
     * Counterpart to Solidity's `uint136` operator.
     *
     * Requirements:
     *
     * - input must fit into 136 bits
     */
    function toUint136(uint256 value) internal pure returns (uint136) {
        if (value > type(uint136).max) {
            revert SafeCastOverflowedUintDowncast(136, value);
        }
        return uint136(value);
    }

    /**
     * @dev Returns the downcasted uint128 from uint256, reverting on
     * overflow (when the input is greater than largest uint128).
     *
     * Counterpart to Solidity's `uint128` operator.
     *
     * Requirements:
     *
     * - input must fit into 128 bits
     */
    function toUint128(uint256 value) internal pure returns (uint128) {
        if (value > type(uint128).max) {
            revert SafeCastOverflowedUintDowncast(128, value);
        }
        return uint128(value);
    }

    /**
     * @dev Returns the downcasted uint120 from uint256, reverting on
     * overflow (when the input is greater than largest uint120).
     *
     * Counterpart to Solidity's `uint120` operator.
     *
     * Requirements:
     *
     * - input must fit into 120 bits
     */
    function toUint120(uint256 value) internal pure returns (uint120) {
        if (value > type(uint120).max) {
            revert SafeCastOverflowedUintDowncast(120, value);
        }
        return uint120(value);
    }

    /**
     * @dev Returns the downcasted uint112 from uint256, reverting on
     * overflow (when the input is greater than largest uint112).
     *
     * Counterpart to Solidity's `uint112` operator.
     *
     * Requirements:
     *
     * - input must fit into 112 bits
     */
    function toUint112(uint256 value) internal pure returns (uint112) {
        if (value > type(uint112).max) {
            revert SafeCastOverflowedUintDowncast(112, value);
        }
        return uint112(value);
    }

    /**
     * @dev Returns the downcasted uint104 from uint256, reverting on
     * overflow (when the input is greater than largest uint104).
     *
     * Counterpart to Solidity's `uint104` operator.
     *
     * Requirements:
     *
     * - input must fit into 104 bits
     */
    function toUint104(uint256 value) internal pure returns (uint104) {
        if (value > type(uint104).max) {
            revert SafeCastOverflowedUintDowncast(104, value);
        }
        return uint104(value);
    }

    /**
     * @dev Returns the downcasted uint96 from uint256, reverting on
     * overflow (when the input is greater than largest uint96).
     *
     * Counterpart to Solidity's `uint96` operator.
     *
     * Requirements:
     *
     * - input must fit into 96 bits
     */
    function toUint96(uint256 value) internal pure returns (uint96) {
        if (value > type(uint96).max) {
            revert SafeCastOverflowedUintDowncast(96, value);
        }
        return uint96(value);
    }

    /**
     * @dev Returns the downcasted uint88 from uint256, reverting on
     * overflow (when the input is greater than largest uint88).
     *
     * Counterpart to Solidity's `uint88` operator.
     *
     * Requirements:
     *
     * - input must fit into 88 bits
     */
    function toUint88(uint256 value) internal pure returns (uint88) {
        if (value > type(uint88).max) {
            revert SafeCastOverflowedUintDowncast(88, value);
        }
        return uint88(value);
    }

    /**
     * @dev Returns the downcasted uint80 from uint256, reverting on
     * overflow (when the input is greater than largest uint80).
     *
     * Counterpart to Solidity's `uint80` operator.
     *
     * Requirements:
     *
     * - input must fit into 80 bits
     */
    function toUint80(uint256 value) internal pure returns (uint80) {
        if (value > type(uint80).max) {
            revert SafeCastOverflowedUintDowncast(80, value);
        }
        return uint80(value);
    }

    /**
     * @dev Returns the downcasted uint72 from uint256, reverting on
     * overflow (when the input is greater than largest uint72).
     *
     * Counterpart to Solidity's `uint72` operator.
     *
     * Requirements:
     *
     * - input must fit into 72 bits
     */
    function toUint72(uint256 value) internal pure returns (uint72) {
        if (value > type(uint72).max) {
            revert SafeCastOverflowedUintDowncast(72, value);
        }
        return uint72(value);
    }

    /**
     * @dev Returns the downcasted uint64 from uint256, reverting on
     * overflow (when the input is greater than largest uint64).
     *
     * Counterpart to Solidity's `uint64` operator.
     *
     * Requirements:
     *
     * - input must fit into 64 bits
     */
    function toUint64(uint256 value) internal pure returns (uint64) {
        if (value > type(uint64).max) {
            revert SafeCastOverflowedUintDowncast(64, value);
        }
        return uint64(value);
    }

    /**
     * @dev Returns the downcasted uint56 from uint256, reverting on
     * overflow (when the input is greater than largest uint56).
     *
     * Counterpart to Solidity's `uint56` operator.
     *
     * Requirements:
     *
     * - input must fit into 56 bits
     */
    function toUint56(uint256 value) internal pure returns (uint56) {
        if (value > type(uint56).max) {
            revert SafeCastOverflowedUintDowncast(56, value);
        }
        return uint56(value);
    }

    /**
     * @dev Returns the downcasted uint48 from uint256, reverting on
     * overflow (when the input is greater than largest uint48).
     *
     * Counterpart to Solidity's `uint48` operator.
     *
     * Requirements:
     *
     * - input must fit into 48 bits
     */
    function toUint48(uint256 value) internal pure returns (uint48) {
        if (value > type(uint48).max) {
            revert SafeCastOverflowedUintDowncast(48, value);
        }
        return uint48(value);
    }

    /**
     * @dev Returns the downcasted uint40 from uint256, reverting on
     * overflow (when the input is greater than largest uint40).
     *
     * Counterpart to Solidity's `uint40` operator.
     *
     * Requirements:
     *
     * - input must fit into 40 bits
     */
    function toUint40(uint256 value) internal pure returns (uint40) {
        if (value > type(uint40).max) {
            revert SafeCastOverflowedUintDowncast(40, value);
        }
        return uint40(value);
    }

    /**
     * @dev Returns the downcasted uint32 from uint256, reverting on
     * overflow (when the input is greater than largest uint32).
     *
     * Counterpart to Solidity's `uint32` operator.
     *
     * Requirements:
     *
     * - input must fit into 32 bits
     */
    function toUint32(uint256 value) internal pure returns (uint32) {
        if (value > type(uint32).max) {
            revert SafeCastOverflowedUintDowncast(32, value);
        }
        return uint32(value);
    }

    /**
     * @dev Returns the downcasted uint24 from uint256, reverting on
     * overflow (when the input is greater than largest uint24).
     *
     * Counterpart to Solidity's `uint24` operator.
     *
     * Requirements:
     *
     * - input must fit into 24 bits
     */
    function toUint24(uint256 value) internal pure returns (uint24) {
        if (value > type(uint24).max) {
            revert SafeCastOverflowedUintDowncast(24, value);
        }
        return uint24(value);
    }

    /**
     * @dev Returns the downcasted uint16 from uint256, reverting on
     * overflow (when the input is greater than largest uint16).
     *
     * Counterpart to Solidity's `uint16` operator.
     *
     * Requirements:
     *
     * - input must fit into 16 bits
     */
    function toUint16(uint256 value) internal pure returns (uint16) {
        if (value > type(uint16).max) {
            revert SafeCastOverflowedUintDowncast(16, value);
        }
        return uint16(value);
    }

    /**
     * @dev Returns the downcasted uint8 from uint256, reverting on
     * overflow (when the input is greater than largest uint8).
     *
     * Counterpart to Solidity's `uint8` operator.
     *
     * Requirements:
     *
     * - input must fit into 8 bits
     */
    function toUint8(uint256 value) internal pure returns (uint8) {
        if (value > type(uint8).max) {
            revert SafeCastOverflowedUintDowncast(8, value);
        }
        return uint8(value);
    }

    /**
     * @dev Converts a signed int256 into an unsigned uint256.
     *
     * Requirements:
     *
     * - input must be greater than or equal to 0.
     */
    function toUint256(int256 value) internal pure returns (uint256) {
        if (value < 0) {
            revert SafeCastOverflowedIntToUint(value);
        }
        return uint256(value);
    }

    /**
     * @dev Returns the downcasted int248 from int256, reverting on
     * overflow (when the input is less than smallest int248 or
     * greater than largest int248).
     *
     * Counterpart to Solidity's `int248` operator.
     *
     * Requirements:
     *
     * - input must fit into 248 bits
     */
    function toInt248(int256 value) internal pure returns (int248 downcasted) {
        downcasted = int248(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(248, value);
        }
    }

    /**
     * @dev Returns the downcasted int240 from int256, reverting on
     * overflow (when the input is less than smallest int240 or
     * greater than largest int240).
     *
     * Counterpart to Solidity's `int240` operator.
     *
     * Requirements:
     *
     * - input must fit into 240 bits
     */
    function toInt240(int256 value) internal pure returns (int240 downcasted) {
        downcasted = int240(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(240, value);
        }
    }

    /**
     * @dev Returns the downcasted int232 from int256, reverting on
     * overflow (when the input is less than smallest int232 or
     * greater than largest int232).
     *
     * Counterpart to Solidity's `int232` operator.
     *
     * Requirements:
     *
     * - input must fit into 232 bits
     */
    function toInt232(int256 value) internal pure returns (int232 downcasted) {
        downcasted = int232(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(232, value);
        }
    }

    /**
     * @dev Returns the downcasted int224 from int256, reverting on
     * overflow (when the input is less than smallest int224 or
     * greater than largest int224).
     *
     * Counterpart to Solidity's `int224` operator.
     *
     * Requirements:
     *
     * - input must fit into 224 bits
     */
    function toInt224(int256 value) internal pure returns (int224 downcasted) {
        downcasted = int224(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(224, value);
        }
    }

    /**
     * @dev Returns the downcasted int216 from int256, reverting on
     * overflow (when the input is less than smallest int216 or
     * greater than largest int216).
     *
     * Counterpart to Solidity's `int216` operator.
     *
     * Requirements:
     *
     * - input must fit into 216 bits
     */
    function toInt216(int256 value) internal pure returns (int216 downcasted) {
        downcasted = int216(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(216, value);
        }
    }

    /**
     * @dev Returns the downcasted int208 from int256, reverting on
     * overflow (when the input is less than smallest int208 or
     * greater than largest int208).
     *
     * Counterpart to Solidity's `int208` operator.
     *
     * Requirements:
     *
     * - input must fit into 208 bits
     */
    function toInt208(int256 value) internal pure returns (int208 downcasted) {
        downcasted = int208(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(208, value);
        }
    }

    /**
     * @dev Returns the downcasted int200 from int256, reverting on
     * overflow (when the input is less than smallest int200 or
     * greater than largest int200).
     *
     * Counterpart to Solidity's `int200` operator.
     *
     * Requirements:
     *
     * - input must fit into 200 bits
     */
    function toInt200(int256 value) internal pure returns (int200 downcasted) {
        downcasted = int200(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(200, value);
        }
    }

    /**
     * @dev Returns the downcasted int192 from int256, reverting on
     * overflow (when the input is less than smallest int192 or
     * greater than largest int192).
     *
     * Counterpart to Solidity's `int192` operator.
     *
     * Requirements:
     *
     * - input must fit into 192 bits
     */
    function toInt192(int256 value) internal pure returns (int192 downcasted) {
        downcasted = int192(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(192, value);
        }
    }

    /**
     * @dev Returns the downcasted int184 from int256, reverting on
     * overflow (when the input is less than smallest int184 or
     * greater than largest int184).
     *
     * Counterpart to Solidity's `int184` operator.
     *
     * Requirements:
     *
     * - input must fit into 184 bits
     */
    function toInt184(int256 value) internal pure returns (int184 downcasted) {
        downcasted = int184(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(184, value);
        }
    }

    /**
     * @dev Returns the downcasted int176 from int256, reverting on
     * overflow (when the input is less than smallest int176 or
     * greater than largest int176).
     *
     * Counterpart to Solidity's `int176` operator.
     *
     * Requirements:
     *
     * - input must fit into 176 bits
     */
    function toInt176(int256 value) internal pure returns (int176 downcasted) {
        downcasted = int176(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(176, value);
        }
    }

    /**
     * @dev Returns the downcasted int168 from int256, reverting on
     * overflow (when the input is less than smallest int168 or
     * greater than largest int168).
     *
     * Counterpart to Solidity's `int168` operator.
     *
     * Requirements:
     *
     * - input must fit into 168 bits
     */
    function toInt168(int256 value) internal pure returns (int168 downcasted) {
        downcasted = int168(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(168, value);
        }
    }

    /**
     * @dev Returns the downcasted int160 from int256, reverting on
     * overflow (when the input is less than smallest int160 or
     * greater than largest int160).
     *
     * Counterpart to Solidity's `int160` operator.
     *
     * Requirements:
     *
     * - input must fit into 160 bits
     */
    function toInt160(int256 value) internal pure returns (int160 downcasted) {
        downcasted = int160(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(160, value);
        }
    }

    /**
     * @dev Returns the downcasted int152 from int256, reverting on
     * overflow (when the input is less than smallest int152 or
     * greater than largest int152).
     *
     * Counterpart to Solidity's `int152` operator.
     *
     * Requirements:
     *
     * - input must fit into 152 bits
     */
    function toInt152(int256 value) internal pure returns (int152 downcasted) {
        downcasted = int152(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(152, value);
        }
    }

    /**
     * @dev Returns the downcasted int144 from int256, reverting on
     * overflow (when the input is less than smallest int144 or
     * greater than largest int144).
     *
     * Counterpart to Solidity's `int144` operator.
     *
     * Requirements:
     *
     * - input must fit into 144 bits
     */
    function toInt144(int256 value) internal pure returns (int144 downcasted) {
        downcasted = int144(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(144, value);
        }
    }

    /**
     * @dev Returns the downcasted int136 from int256, reverting on
     * overflow (when the input is less than smallest int136 or
     * greater than largest int136).
     *
     * Counterpart to Solidity's `int136` operator.
     *
     * Requirements:
     *
     * - input must fit into 136 bits
     */
    function toInt136(int256 value) internal pure returns (int136 downcasted) {
        downcasted = int136(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(136, value);
        }
    }

    /**
     * @dev Returns the downcasted int128 from int256, reverting on
     * overflow (when the input is less than smallest int128 or
     * greater than largest int128).
     *
     * Counterpart to Solidity's `int128` operator.
     *
     * Requirements:
     *
     * - input must fit into 128 bits
     */
    function toInt128(int256 value) internal pure returns (int128 downcasted) {
        downcasted = int128(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(128, value);
        }
    }

    /**
     * @dev Returns the downcasted int120 from int256, reverting on
     * overflow (when the input is less than smallest int120 or
     * greater than largest int120).
     *
     * Counterpart to Solidity's `int120` operator.
     *
     * Requirements:
     *
     * - input must fit into 120 bits
     */
    function toInt120(int256 value) internal pure returns (int120 downcasted) {
        downcasted = int120(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(120, value);
        }
    }

    /**
     * @dev Returns the downcasted int112 from int256, reverting on
     * overflow (when the input is less than smallest int112 or
     * greater than largest int112).
     *
     * Counterpart to Solidity's `int112` operator.
     *
     * Requirements:
     *
     * - input must fit into 112 bits
     */
    function toInt112(int256 value) internal pure returns (int112 downcasted) {
        downcasted = int112(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(112, value);
        }
    }

    /**
     * @dev Returns the downcasted int104 from int256, reverting on
     * overflow (when the input is less than smallest int104 or
     * greater than largest int104).
     *
     * Counterpart to Solidity's `int104` operator.
     *
     * Requirements:
     *
     * - input must fit into 104 bits
     */
    function toInt104(int256 value) internal pure returns (int104 downcasted) {
        downcasted = int104(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(104, value);
        }
    }

    /**
     * @dev Returns the downcasted int96 from int256, reverting on
     * overflow (when the input is less than smallest int96 or
     * greater than largest int96).
     *
     * Counterpart to Solidity's `int96` operator.
     *
     * Requirements:
     *
     * - input must fit into 96 bits
     */
    function toInt96(int256 value) internal pure returns (int96 downcasted) {
        downcasted = int96(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(96, value);
        }
    }

    /**
     * @dev Returns the downcasted int88 from int256, reverting on
     * overflow (when the input is less than smallest int88 or
     * greater than largest int88).
     *
     * Counterpart to Solidity's `int88` operator.
     *
     * Requirements:
     *
     * - input must fit into 88 bits
     */
    function toInt88(int256 value) internal pure returns (int88 downcasted) {
        downcasted = int88(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(88, value);
        }
    }

    /**
     * @dev Returns the downcasted int80 from int256, reverting on
     * overflow (when the input is less than smallest int80 or
     * greater than largest int80).
     *
     * Counterpart to Solidity's `int80` operator.
     *
     * Requirements:
     *
     * - input must fit into 80 bits
     */
    function toInt80(int256 value) internal pure returns (int80 downcasted) {
        downcasted = int80(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(80, value);
        }
    }

    /**
     * @dev Returns the downcasted int72 from int256, reverting on
     * overflow (when the input is less than smallest int72 or
     * greater than largest int72).
     *
     * Counterpart to Solidity's `int72` operator.
     *
     * Requirements:
     *
     * - input must fit into 72 bits
     */
    function toInt72(int256 value) internal pure returns (int72 downcasted) {
        downcasted = int72(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(72, value);
        }
    }

    /**
     * @dev Returns the downcasted int64 from int256, reverting on
     * overflow (when the input is less than smallest int64 or
     * greater than largest int64).
     *
     * Counterpart to Solidity's `int64` operator.
     *
     * Requirements:
     *
     * - input must fit into 64 bits
     */
    function toInt64(int256 value) internal pure returns (int64 downcasted) {
        downcasted = int64(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(64, value);
        }
    }

    /**
     * @dev Returns the downcasted int56 from int256, reverting on
     * overflow (when the input is less than smallest int56 or
     * greater than largest int56).
     *
     * Counterpart to Solidity's `int56` operator.
     *
     * Requirements:
     *
     * - input must fit into 56 bits
     */
    function toInt56(int256 value) internal pure returns (int56 downcasted) {
        downcasted = int56(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(56, value);
        }
    }

    /**
     * @dev Returns the downcasted int48 from int256, reverting on
     * overflow (when the input is less than smallest int48 or
     * greater than largest int48).
     *
     * Counterpart to Solidity's `int48` operator.
     *
     * Requirements:
     *
     * - input must fit into 48 bits
     */
    function toInt48(int256 value) internal pure returns (int48 downcasted) {
        downcasted = int48(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(48, value);
        }
    }

    /**
     * @dev Returns the downcasted int40 from int256, reverting on
     * overflow (when the input is less than smallest int40 or
     * greater than largest int40).
     *
     * Counterpart to Solidity's `int40` operator.
     *
     * Requirements:
     *
     * - input must fit into 40 bits
     */
    function toInt40(int256 value) internal pure returns (int40 downcasted) {
        downcasted = int40(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(40, value);
        }
    }

    /**
     * @dev Returns the downcasted int32 from int256, reverting on
     * overflow (when the input is less than smallest int32 or
     * greater than largest int32).
     *
     * Counterpart to Solidity's `int32` operator.
     *
     * Requirements:
     *
     * - input must fit into 32 bits
     */
    function toInt32(int256 value) internal pure returns (int32 downcasted) {
        downcasted = int32(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(32, value);
        }
    }

    /**
     * @dev Returns the downcasted int24 from int256, reverting on
     * overflow (when the input is less than smallest int24 or
     * greater than largest int24).
     *
     * Counterpart to Solidity's `int24` operator.
     *
     * Requirements:
     *
     * - input must fit into 24 bits
     */
    function toInt24(int256 value) internal pure returns (int24 downcasted) {
        downcasted = int24(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(24, value);
        }
    }

    /**
     * @dev Returns the downcasted int16 from int256, reverting on
     * overflow (when the input is less than smallest int16 or
     * greater than largest int16).
     *
     * Counterpart to Solidity's `int16` operator.
     *
     * Requirements:
     *
     * - input must fit into 16 bits
     */
    function toInt16(int256 value) internal pure returns (int16 downcasted) {
        downcasted = int16(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(16, value);
        }
    }

    /**
     * @dev Returns the downcasted int8 from int256, reverting on
     * overflow (when the input is less than smallest int8 or
     * greater than largest int8).
     *
     * Counterpart to Solidity's `int8` operator.
     *
     * Requirements:
     *
     * - input must fit into 8 bits
     */
    function toInt8(int256 value) internal pure returns (int8 downcasted) {
        downcasted = int8(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(8, value);
        }
    }

    /**
     * @dev Converts an unsigned uint256 into a signed int256.
     *
     * Requirements:
     *
     * - input must be less than or equal to maxInt256.
     */
    function toInt256(uint256 value) internal pure returns (int256) {
        // Note: Unsafe cast below is okay because `type(int256).max` is guaranteed to be positive
        if (value > uint256(type(int256).max)) {
            revert SafeCastOverflowedUintToInt(value);
        }
        return int256(value);
    }
}


// File: @openzeppelin/contracts/utils/math/SignedMath.sol

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (utils/math/SignedMath.sol)

pragma solidity ^0.8.20;

/**
 * @dev Standard signed math utilities missing in the Solidity language.
 */
library SignedMath {
    /**
     * @dev Returns the largest of two signed numbers.
     */
    function max(int256 a, int256 b) internal pure returns (int256) {
        return a > b ? a : b;
    }

    /**
     * @dev Returns the smallest of two signed numbers.
     */
    function min(int256 a, int256 b) internal pure returns (int256) {
        return a < b ? a : b;
    }

    /**
     * @dev Returns the average of two signed numbers without overflow.
     * The result is rounded towards zero.
     */
    function average(int256 a, int256 b) internal pure returns (int256) {
        // Formula from the book "Hacker's Delight"
        int256 x = (a & b) + ((a ^ b) >> 1);
        return x + (int256(uint256(x) >> 255) & (a ^ b));
    }

    /**
     * @dev Returns the absolute unsigned value of a signed value.
     */
    function abs(int256 n) internal pure returns (uint256) {
        unchecked {
            // must be unchecked in order to support `n = type(int256).min`
            return uint256(n >= 0 ? n : -n);
        }
    }
}


// File: @openzeppelin/contracts/utils/Nonces.sol

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (utils/Nonces.sol)
pragma solidity ^0.8.20;

/**
 * @dev Provides tracking nonces for addresses. Nonces will only increment.
 */
abstract contract Nonces {
    /**
     * @dev The nonce used for an `account` is not the expected current nonce.
     */
    error InvalidAccountNonce(address account, uint256 currentNonce);

    mapping(address account => uint256) private _nonces;

    /**
     * @dev Returns the next unused nonce for an address.
     */
    function nonces(address owner) public view virtual returns (uint256) {
        return _nonces[owner];
    }

    /**
     * @dev Consumes a nonce.
     *
     * Returns the current value and increments nonce.
     */
    function _useNonce(address owner) internal virtual returns (uint256) {
        // For each account, the nonce has an initial value of 0, can only be incremented by one, and cannot be
        // decremented or reset. This guarantees that the nonce never overflows.
        unchecked {
            // It is important to do x++ and not ++x here.
            return _nonces[owner]++;
        }
    }

    /**
     * @dev Same as {_useNonce} but checking that `nonce` is the next valid for `owner`.
     */
    function _useCheckedNonce(address owner, uint256 nonce) internal virtual {
        uint256 current = _useNonce(owner);
        if (nonce != current) {
            revert InvalidAccountNonce(owner, current);
        }
    }
}


// File: @openzeppelin/contracts/utils/ShortStrings.sol

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (utils/ShortStrings.sol)

pragma solidity ^0.8.20;

import {StorageSlot} from "./StorageSlot.sol";

// | string  | 0xAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA   |
// | length  | 0x                                                              BB |
type ShortString is bytes32;

/**
 * @dev This library provides functions to convert short memory strings
 * into a `ShortString` type that can be used as an immutable variable.
 *
 * Strings of arbitrary length can be optimized using this library if
 * they are short enough (up to 31 bytes) by packing them with their
 * length (1 byte) in a single EVM word (32 bytes). Additionally, a
 * fallback mechanism can be used for every other case.
 *
 * Usage example:
 *
 * ```solidity
 * contract Named {
 *     using ShortStrings for *;
 *
 *     ShortString private immutable _name;
 *     string private _nameFallback;
 *
 *     constructor(string memory contractName) {
 *         _name = contractName.toShortStringWithFallback(_nameFallback);
 *     }
 *
 *     function name() external view returns (string memory) {
 *         return _name.toStringWithFallback(_nameFallback);
 *     }
 * }
 * ```
 */
library ShortStrings {
    // Used as an identifier for strings longer than 31 bytes.
    bytes32 private constant FALLBACK_SENTINEL = 0x00000000000000000000000000000000000000000000000000000000000000FF;

    error StringTooLong(string str);
    error InvalidShortString();

    /**
     * @dev Encode a string of at most 31 chars into a `ShortString`.
     *
     * This will trigger a `StringTooLong` error is the input string is too long.
     */
    function toShortString(string memory str) internal pure returns (ShortString) {
        bytes memory bstr = bytes(str);
        if (bstr.length > 31) {
            revert StringTooLong(str);
        }
        return ShortString.wrap(bytes32(uint256(bytes32(bstr)) | bstr.length));
    }

    /**
     * @dev Decode a `ShortString` back to a "normal" string.
     */
    function toString(ShortString sstr) internal pure returns (string memory) {
        uint256 len = byteLength(sstr);
        // using `new string(len)` would work locally but is not memory safe.
        string memory str = new string(32);
        /// @solidity memory-safe-assembly
        assembly {
            mstore(str, len)
            mstore(add(str, 0x20), sstr)
        }
        return str;
    }

    /**
     * @dev Return the length of a `ShortString`.
     */
    function byteLength(ShortString sstr) internal pure returns (uint256) {
        uint256 result = uint256(ShortString.unwrap(sstr)) & 0xFF;
        if (result > 31) {
            revert InvalidShortString();
        }
        return result;
    }

    /**
     * @dev Encode a string into a `ShortString`, or write it to storage if it is too long.
     */
    function toShortStringWithFallback(string memory value, string storage store) internal returns (ShortString) {
        if (bytes(value).length < 32) {
            return toShortString(value);
        } else {
            StorageSlot.getStringSlot(store).value = value;
            return ShortString.wrap(FALLBACK_SENTINEL);
        }
    }

    /**
     * @dev Decode a string that was encoded to `ShortString` or written to storage using {setWithFallback}.
     */
    function toStringWithFallback(ShortString value, string storage store) internal pure returns (string memory) {
        if (ShortString.unwrap(value) != FALLBACK_SENTINEL) {
            return toString(value);
        } else {
            return store;
        }
    }

    /**
     * @dev Return the length of a string that was encoded to `ShortString` or written to storage using
     * {setWithFallback}.
     *
     * WARNING: This will return the "byte length" of the string. This may not reflect the actual length in terms of
     * actual characters as the UTF-8 encoding of a single character can span over multiple bytes.
     */
    function byteLengthWithFallback(ShortString value, string storage store) internal view returns (uint256) {
        if (ShortString.unwrap(value) != FALLBACK_SENTINEL) {
            return byteLength(value);
        } else {
            return bytes(store).length;
        }
    }
}


// File: @openzeppelin/contracts/utils/StorageSlot.sol

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (utils/StorageSlot.sol)
// This file was procedurally generated from scripts/generate/templates/StorageSlot.js.

pragma solidity ^0.8.20;

/**
 * @dev Library for reading and writing primitive types to specific storage slots.
 *
 * Storage slots are often used to avoid storage conflict when dealing with upgradeable contracts.
 * This library helps with reading and writing to such slots without the need for inline assembly.
 *
 * The functions in this library return Slot structs that contain a `value` member that can be used to read or write.
 *
 * Example usage to set ERC1967 implementation slot:
 * ```solidity
 * contract ERC1967 {
 *     bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
 *
 *     function _getImplementation() internal view returns (address) {
 *         return StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value;
 *     }
 *
 *     function _setImplementation(address newImplementation) internal {
 *         require(newImplementation.code.length > 0);
 *         StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value = newImplementation;
 *     }
 * }
 * ```
 */
library StorageSlot {
    struct AddressSlot {
        address value;
    }

    struct BooleanSlot {
        bool value;
    }

    struct Bytes32Slot {
        bytes32 value;
    }

    struct Uint256Slot {
        uint256 value;
    }

    struct StringSlot {
        string value;
    }

    struct BytesSlot {
        bytes value;
    }

    /**
     * @dev Returns an `AddressSlot` with member `value` located at `slot`.
     */
    function getAddressSlot(bytes32 slot) internal pure returns (AddressSlot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `BooleanSlot` with member `value` located at `slot`.
     */
    function getBooleanSlot(bytes32 slot) internal pure returns (BooleanSlot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `Bytes32Slot` with member `value` located at `slot`.
     */
    function getBytes32Slot(bytes32 slot) internal pure returns (Bytes32Slot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `Uint256Slot` with member `value` located at `slot`.
     */
    function getUint256Slot(bytes32 slot) internal pure returns (Uint256Slot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `StringSlot` with member `value` located at `slot`.
     */
    function getStringSlot(bytes32 slot) internal pure returns (StringSlot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `StringSlot` representation of the string storage pointer `store`.
     */
    function getStringSlot(string storage store) internal pure returns (StringSlot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := store.slot
        }
    }

    /**
     * @dev Returns an `BytesSlot` with member `value` located at `slot`.
     */
    function getBytesSlot(bytes32 slot) internal pure returns (BytesSlot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `BytesSlot` representation of the bytes storage pointer `store`.
     */
    function getBytesSlot(bytes storage store) internal pure returns (BytesSlot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := store.slot
        }
    }
}


// File: @openzeppelin/contracts/utils/Strings.sol

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (utils/Strings.sol)

pragma solidity ^0.8.20;

import {Math} from "./math/Math.sol";
import {SignedMath} from "./math/SignedMath.sol";

/**
 * @dev String operations.
 */
library Strings {
    bytes16 private constant HEX_DIGITS = "0123456789abcdef";
    uint8 private constant ADDRESS_LENGTH = 20;

    /**
     * @dev The `value` string doesn't fit in the specified `length`.
     */
    error StringsInsufficientHexLength(uint256 value, uint256 length);

    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        unchecked {
            uint256 length = Math.log10(value) + 1;
            string memory buffer = new string(length);
            uint256 ptr;
            /// @solidity memory-safe-assembly
            assembly {
                ptr := add(buffer, add(32, length))
            }
            while (true) {
                ptr--;
                /// @solidity memory-safe-assembly
                assembly {
                    mstore8(ptr, byte(mod(value, 10), HEX_DIGITS))
                }
                value /= 10;
                if (value == 0) break;
            }
            return buffer;
        }
    }

    /**
     * @dev Converts a `int256` to its ASCII `string` decimal representation.
     */
    function toStringSigned(int256 value) internal pure returns (string memory) {
        return string.concat(value < 0 ? "-" : "", toString(SignedMath.abs(value)));
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation.
     */
    function toHexString(uint256 value) internal pure returns (string memory) {
        unchecked {
            return toHexString(value, Math.log256(value) + 1);
        }
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.
     */
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        uint256 localValue = value;
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = HEX_DIGITS[localValue & 0xf];
            localValue >>= 4;
        }
        if (localValue != 0) {
            revert StringsInsufficientHexLength(value, length);
        }
        return string(buffer);
    }

    /**
     * @dev Converts an `address` with fixed length of 20 bytes to its not checksummed ASCII `string` hexadecimal
     * representation.
     */
    function toHexString(address addr) internal pure returns (string memory) {
        return toHexString(uint256(uint160(addr)), ADDRESS_LENGTH);
    }

    /**
     * @dev Returns true if the two strings are equal.
     */
    function equal(string memory a, string memory b) internal pure returns (bool) {
        return bytes(a).length == bytes(b).length && keccak256(bytes(a)) == keccak256(bytes(b));
    }
}


// File: contracts/BalancerPoolToken.sol

// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.24;

import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { IERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import { ERC165 } from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import { EIP712 } from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Nonces } from "@openzeppelin/contracts/utils/Nonces.sol";

import { IRateProvider } from "@balancer-labs/v3-interfaces/contracts/solidity-utils/helpers/IRateProvider.sol";
import { IVault } from "@balancer-labs/v3-interfaces/contracts/vault/IVault.sol";

import { VaultGuard } from "./VaultGuard.sol";

/**
 * @notice `BalancerPoolToken` is a fully ERC20-compatible token to be used as the base contract for Balancer Pools,
 * with all the data and implementation delegated to the ERC20Multitoken contract.

 * @dev Implementation of the ERC-20 Permit extension allowing approvals to be made via signatures, as defined in
 * https://eips.ethereum.org/EIPS/eip-2612[ERC-2612].
 */
contract BalancerPoolToken is IERC20, IERC20Metadata, IERC20Permit, IRateProvider, EIP712, Nonces, ERC165, VaultGuard {
    bytes32 public constant PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    /**
     * @notice Operation failed due to an expired permit signature.
     * @param deadline The permit deadline that expired
     */
    error ERC2612ExpiredSignature(uint256 deadline);

    /**
     * @notice Operation failed due to a non-matching signature.
     * @param signer The address corresponding to the signature provider
     * @param owner The address of the owner (expected value of the signature provider)
     */
    error ERC2612InvalidSigner(address signer, address owner);

    // EIP712 also defines _name.
    string private _bptName;
    string private _bptSymbol;

    constructor(IVault vault_, string memory bptName, string memory bptSymbol) EIP712(bptName, "1") VaultGuard(vault_) {
        _bptName = bptName;
        _bptSymbol = bptSymbol;
    }

    /// @inheritdoc IERC20Metadata
    function name() external view returns (string memory) {
        return _bptName;
    }

    /// @inheritdoc IERC20Metadata
    function symbol() external view returns (string memory) {
        return _bptSymbol;
    }

    /// @inheritdoc IERC20Metadata
    function decimals() external pure returns (uint8) {
        // Always 18 decimals for BPT.
        return 18;
    }

    /// @inheritdoc IERC20
    function totalSupply() public view returns (uint256) {
        return _vault.totalSupply(address(this));
    }

    function getVault() public view returns (IVault) {
        return _vault;
    }

    /// @inheritdoc IERC20
    function balanceOf(address account) external view returns (uint256) {
        return _vault.balanceOf(address(this), account);
    }

    /// @inheritdoc IERC20
    function transfer(address to, uint256 amount) external returns (bool) {
        // Vault will perform the transfer and call emitTransfer to emit the event from this contract.
        _vault.transfer(msg.sender, to, amount);
        return true;
    }

    /// @inheritdoc IERC20
    function allowance(address owner, address spender) external view returns (uint256) {
        return _vault.allowance(address(this), owner, spender);
    }

    /// @inheritdoc IERC20
    function approve(address spender, uint256 amount) external returns (bool) {
        // Vault will perform the approval and call emitApproval to emit the event from this contract.
        _vault.approve(msg.sender, spender, amount);
        return true;
    }

    /// @inheritdoc IERC20
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        // Vault will perform the transfer and call emitTransfer to emit the event from this contract.
        _vault.transferFrom(msg.sender, from, to, amount);
        return true;
    }

    /**
     * Accounting is centralized in the MultiToken contract, and the actual transfers and approvals are done there.
     * Operations can be initiated from either the token contract or the MultiToken.
     *
     * To maintain compliance with the ERC-20 standard, and conform to the expectations of off-chain processes,
     * the MultiToken calls `emitTransfer` and `emitApproval` during those operations, so that the event is emitted
     * only from the token contract. These events are NOT defined in the MultiToken contract.
     */

    /// @dev Emit the Transfer event. This function can only be called by the MultiToken.
    function emitTransfer(address from, address to, uint256 amount) external onlyVault {
        emit Transfer(from, to, amount);
    }

    /// @dev Emit the Approval event. This function can only be called by the MultiToken.
    function emitApproval(address owner, address spender, uint256 amount) external onlyVault {
        emit Approval(owner, spender, amount);
    }

    // @inheritdoc IERC20Permit
    function permit(
        address owner,
        address spender,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public virtual {
        // solhint-disable-next-line not-rely-on-time
        if (block.timestamp > deadline) {
            revert ERC2612ExpiredSignature(deadline);
        }

        bytes32 structHash = keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, amount, _useNonce(owner), deadline));

        bytes32 hash = _hashTypedDataV4(structHash);

        address signer = ECDSA.recover(hash, v, r, s);
        if (signer != owner) {
            revert ERC2612InvalidSigner(signer, owner);
        }

        _vault.approve(owner, spender, amount);
    }

    // @inheritdoc IERC20Permit
    function nonces(address owner) public view virtual override(IERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }

    /// @notice Increment the sender's nonce to revoke any currently granted (but not yet executed) `permit`.
    function incrementNonce() external {
        _useNonce(msg.sender);
    }

    // @inheritdoc IERC20Permit
    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() external view virtual returns (bytes32) {
        return _domainSeparatorV4();
    }

    /**
     * @notice Get the BPT rate, which is defined as: pool invariant/total supply.
     * @dev The VaultExtension contract defines a default implementation (`getBptRate`) to calculate the rate
     * of any given pool, which should be sufficient in nearly all cases.
     *
     * @return rate Rate of the pool's BPT
     */
    function getRate() public view virtual returns (uint256) {
        return getVault().getBptRate(address(this));
    }
}


// File: contracts/BasePoolMath.sol

// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.24;

import { IBasePool } from "@balancer-labs/v3-interfaces/contracts/vault/IBasePool.sol";
import { Rounding } from "@balancer-labs/v3-interfaces/contracts/vault/VaultTypes.sol";

import { FixedPoint } from "@balancer-labs/v3-solidity-utils/contracts/math/FixedPoint.sol";

library BasePoolMath {
    using FixedPoint for uint256;

    /**
     * @notice An add liquidity operation increased the invariant above the limit.
     * @dev This value is determined by each pool type, and depends on the specific math used to compute
     * the price curve.
     *
     * @param invariantRatio The ratio of the new invariant (after an operation) to the old
     * @param maxInvariantRatio The maximum allowed invariant ratio
     */
    error InvariantRatioAboveMax(uint256 invariantRatio, uint256 maxInvariantRatio);

    /**
     * @notice A remove liquidity operation decreased the invariant below the limit.
     * @dev This value is determined by each pool type, and depends on the specific math used to compute
     * the price curve.
     *
     * @param invariantRatio The ratio of the new invariant (after an operation) to the old
     * @param minInvariantRatio The minimum allowed invariant ratio
     */
    error InvariantRatioBelowMin(uint256 invariantRatio, uint256 minInvariantRatio);

    // For security reasons, to help ensure that for all possible "round trip" paths the caller always receives the
    // same or fewer tokens than supplied, we have chosen the rounding direction to favor the protocol in all cases.

    /**
     * @notice Computes the proportional amounts of tokens to be deposited into the pool.
     * @dev This function computes the amount of each token that needs to be deposited in order to mint a specific
     * amount of pool tokens (BPT). It ensures that the amounts of tokens deposited are proportional to the current
     * pool balances.
     *
     * Calculation: For each token, amountIn = balance * (bptAmountOut / bptTotalSupply).
     * Rounding up is used to ensure that the pool is not underfunded.
     *
     * @param balances Array of current token balances in the pool
     * @param bptTotalSupply Total supply of the pool tokens (BPT)
     * @param bptAmountOut The amount of pool tokens that need to be minted
     * @return amountsIn Array of amounts for each token to be deposited
     */
    function computeProportionalAmountsIn(
        uint256[] memory balances,
        uint256 bptTotalSupply,
        uint256 bptAmountOut
    ) internal pure returns (uint256[] memory amountsIn) {
        /************************************************************************************
        // computeProportionalAmountsIn                                                    //
        // (per token)                                                                     //
        // aI = amountIn                   /      bptOut      \                            //
        // b = balance           aI = b * | ----------------- |                            //
        // bptOut = bptAmountOut           \  bptTotalSupply  /                            //
        // bpt = bptTotalSupply                                                            //
        ************************************************************************************/

        // Create a new array to hold the amounts of each token to be deposited.
        amountsIn = new uint256[](balances.length);
        for (uint256 i = 0; i < balances.length; ++i) {
            // Since we multiply and divide we don't need to use FP math.
            // We're calculating amounts in so we round up.
            amountsIn[i] = balances[i].mulDivUp(bptAmountOut, bptTotalSupply);
        }
    }

    /**
     * @notice Computes the proportional amounts of tokens to be withdrawn from the pool.
     * @dev This function computes the amount of each token that will be withdrawn in exchange for burning
     * a specific amount of pool tokens (BPT). It ensures that the amounts of tokens withdrawn are proportional
     * to the current pool balances.
     *
     * Calculation: For each token, amountOut = balance * (bptAmountIn / bptTotalSupply).
     * Rounding down is used to prevent withdrawing more than the pool can afford.
     *
     * @param balances Array of current token balances in the pool
     * @param bptTotalSupply Total supply of the pool tokens (BPT)
     * @param bptAmountIn The amount of pool tokens that will be burned
     * @return amountsOut Array of amounts for each token to be withdrawn
     */
    function computeProportionalAmountsOut(
        uint256[] memory balances,
        uint256 bptTotalSupply,
        uint256 bptAmountIn
    ) internal pure returns (uint256[] memory amountsOut) {
        /**********************************************************************************************
        // computeProportionalAmountsOut                                                             //
        // (per token)                                                                               //
        // aO = tokenAmountOut             /        bptIn         \                                  //
        // b = tokenBalance      a0 = b * | ---------------------  |                                 //
        // bptIn = bptAmountIn             \     bptTotalSupply    /                                 //
        // bpt = bptTotalSupply                                                                      //
        **********************************************************************************************/

        // Create a new array to hold the amounts of each token to be withdrawn.
        amountsOut = new uint256[](balances.length);
        for (uint256 i = 0; i < balances.length; ++i) {
            // Since we multiply and divide we don't need to use FP math.
            // Round down since we're calculating amounts out.
            amountsOut[i] = (balances[i] * bptAmountIn) / bptTotalSupply;
        }
    }

    /**
     * @notice Computes the amount of pool tokens (BPT) to be minted for an unbalanced liquidity addition.
     * @dev This function handles liquidity addition where the proportion of tokens deposited does not match
     * the current pool composition. It considers the current balances, exact amounts of tokens to be added,
     * total supply, and swap fee percentage. The function calculates a new invariant with the added tokens,
     * applying swap fees if necessary, and then calculates the amount of BPT to mint based on the change
     * in the invariant.
     *
     * @param currentBalances Current pool balances, sorted in token registration order
     * @param exactAmounts Array of exact amounts for each token to be added to the pool
     * @param totalSupply The current total supply of the pool tokens (BPT)
     * @param swapFeePercentage The swap fee percentage applied to the transaction
     * @param pool The pool to which we're adding liquidity
     * @return bptAmountOut The amount of pool tokens (BPT) that will be minted as a result of the liquidity addition
     * @return swapFeeAmounts The amount of swap fees charged for each token
     */
    function computeAddLiquidityUnbalanced(
        uint256[] memory currentBalances,
        uint256[] memory exactAmounts,
        uint256 totalSupply,
        uint256 swapFeePercentage,
        IBasePool pool
    ) internal view returns (uint256 bptAmountOut, uint256[] memory swapFeeAmounts) {
        /***********************************************************************
        //                                                                    //
        // s = totalSupply                                 (iFees - iCur)     //
        // b = tokenBalance                  bptOut = s *  --------------     //
        // bptOut = bptAmountOut                                iCur          //
        // iFees = invariantWithFeesApplied                                   //
        // iCur = currentInvariant                                            //
        // iNew = newInvariant                                                //
        ***********************************************************************/

        // Determine the number of tokens in the pool.
        uint256 numTokens = currentBalances.length;

        // Create a new array to hold the updated balances after the addition.
        uint256[] memory newBalances = new uint256[](numTokens);
        // Create a new array to hold the swap fee amount for each token.
        swapFeeAmounts = new uint256[](numTokens);

        // Loop through each token, updating the balance with the added amount.
        for (uint256 i = 0; i < numTokens; ++i) {
            newBalances[i] = currentBalances[i] + exactAmounts[i] - 1; // Undo balance round up for new balances.
        }

        // Calculate the new invariant ratio by dividing the new invariant by the old invariant.
        // Rounding current invariant up reduces BPT amount out at the end (see comments below).
        uint256 currentInvariant = pool.computeInvariant(currentBalances, Rounding.ROUND_UP);
        // Round down to make `taxableAmount` larger below.
        uint256 invariantRatio = pool.computeInvariant(newBalances, Rounding.ROUND_DOWN).divDown(currentInvariant);

        ensureInvariantRatioBelowMaximumBound(pool, invariantRatio);

        // Loop through each token to apply fees if necessary.
        for (uint256 i = 0; i < numTokens; ++i) {
            // Check if the new balance is greater than the equivalent proportional balance.
            // If so, calculate the taxable amount, rounding in favor of the protocol.
            // We round the second term down to subtract less and get a higher `taxableAmount`,
            // which charges higher swap fees. This will lower `newBalances`, which in turn lowers
            // `invariantWithFeesApplied` below.
            uint256 proportionalTokenBalance = invariantRatio.mulDown(currentBalances[i]);
            if (newBalances[i] > proportionalTokenBalance) {
                uint256 taxableAmount;
                unchecked {
                    taxableAmount = newBalances[i] - proportionalTokenBalance;
                }
                // Calculate the fee amount.
                swapFeeAmounts[i] = taxableAmount.mulUp(swapFeePercentage);

                // Subtract the fee from the new balance.
                // We are essentially imposing swap fees on non-proportional incoming amounts.
                // Note: `swapFeeAmounts` should always be <= `taxableAmount` since `swapFeePercentage` is <= FP(1),
                // but since that's not verifiable within this contract, a checked subtraction is preferred.
                newBalances[i] = newBalances[i] - swapFeeAmounts[i];
            }
        }

        // Calculate the new invariant with fees applied.
        // This invariant should be lower than the original one, so we don't need to check invariant ratio bounds again.
        // Rounding down makes bptAmountOut go down (see comment below).
        uint256 invariantWithFeesApplied = pool.computeInvariant(newBalances, Rounding.ROUND_DOWN);

        // Calculate the amount of BPT to mint. This is done by multiplying the
        // total supply with the ratio of the change in invariant.
        // Since we multiply and divide we don't need to use FP math.
        // Round down since we're calculating BPT amount out. This is the most important result of this function,
        // equivalent to:
        // `totalSupply * (invariantWithFeesApplied / currentInvariant - 1)`

        // Then, to round `bptAmountOut` down we use `invariantWithFeesApplied` rounded down and `currentInvariant`
        // rounded up.
        // If rounding makes `invariantWithFeesApplied` smaller or equal to `currentInvariant`, this would effectively
        // be a donation. In that case we just let checked math revert for simplicity; it's not a valid use-case to
        // support at this point.
        bptAmountOut = (totalSupply * (invariantWithFeesApplied - currentInvariant)) / currentInvariant;
    }

    /**
     * @notice Computes the amount of input token needed to receive an exact amount of pool tokens (BPT) in a
     * single-token liquidity addition.
     * @dev This function is used when a user wants to add liquidity to the pool by specifying the exact amount
     * of pool tokens they want to receive, and the function calculates the corresponding amount of the input token.
     * It considers the current pool balances, total supply, swap fee percentage, and the desired BPT amount.
     *
     * @param currentBalances Array of current token balances in the pool, sorted in token registration order
     * @param tokenInIndex Index of the input token for which the amount needs to be calculated
     * @param exactBptAmountOut Exact amount of pool tokens (BPT) the user wants to receive
     * @param totalSupply The current total supply of the pool tokens (BPT)
     * @param swapFeePercentage The swap fee percentage applied to the taxable amount
     * @param pool The pool to which we're adding liquidity
     * @return amountInWithFee The amount of input token needed, including the swap fee, to receive the exact BPT amount
     * @return swapFeeAmounts The amount of swap fees charged for each token
     */
    function computeAddLiquiditySingleTokenExactOut(
        uint256[] memory currentBalances,
        uint256 tokenInIndex,
        uint256 exactBptAmountOut,
        uint256 totalSupply,
        uint256 swapFeePercentage,
        IBasePool pool
    ) internal view returns (uint256 amountInWithFee, uint256[] memory swapFeeAmounts) {
        // Calculate new supply after minting exactBptAmountOut.
        uint256 newSupply = exactBptAmountOut + totalSupply;

        // Calculate the initial amount of the input token needed for the desired amount of BPT out
        // "divUp" leads to a higher "newBalance", which in turn results in a larger "amountIn".
        // This leads to receiving more tokens for the same amount of BPT minted.
        uint256 invariantRatio = newSupply.divUp(totalSupply);
        ensureInvariantRatioBelowMaximumBound(pool, invariantRatio);

        uint256 newBalance = pool.computeBalance(currentBalances, tokenInIndex, invariantRatio);

        // Compute the amount to be deposited into the pool.
        uint256 amountIn = newBalance - currentBalances[tokenInIndex];

        // Calculate the non-taxable amount, which is the new balance proportionate to the BPT minted.
        // Since we multiply and divide we don't need to use FP math.
        // Rounding down makes `taxableAmount` larger, which in turn makes `fee` larger below.
        uint256 nonTaxableBalance = (newSupply * currentBalances[tokenInIndex]) / totalSupply;

        // Calculate the taxable amount, which is the difference between the actual new balance and
        // the non-taxable balance.
        uint256 taxableAmount = newBalance - nonTaxableBalance;

        // Calculate the swap fee based on the taxable amount and the swap fee percentage.
        uint256 fee = taxableAmount.divUp(swapFeePercentage.complement()) - taxableAmount;

        // Create swap fees amount array and set the single fee we charge.
        swapFeeAmounts = new uint256[](currentBalances.length);
        swapFeeAmounts[tokenInIndex] = fee;

        // Return the total amount of input token needed, including the swap fee.
        amountInWithFee = amountIn + fee;
    }

    /**
     * @notice Computes the amount of pool tokens to burn to receive exact amount out.
     * @param currentBalances Current pool balances, sorted in token registration order
     * @param tokenOutIndex Index of the token to receive in exchange for pool tokens burned
     * @param exactAmountOut Exact amount of tokens to receive
     * @param totalSupply The current total supply of the pool tokens (BPT)
     * @param swapFeePercentage The swap fee percentage applied to the taxable amount
     * @param pool The pool from which we're removing liquidity
     * @return bptAmountIn Amount of pool tokens to burn
     * @return swapFeeAmounts The amount of swap fees charged for each token
     */
    function computeRemoveLiquiditySingleTokenExactOut(
        uint256[] memory currentBalances,
        uint256 tokenOutIndex,
        uint256 exactAmountOut,
        uint256 totalSupply,
        uint256 swapFeePercentage,
        IBasePool pool
    ) internal view returns (uint256 bptAmountIn, uint256[] memory swapFeeAmounts) {
        // Determine the number of tokens in the pool.
        uint256 numTokens = currentBalances.length;

        // Create a new array to hold the updated balances.
        uint256[] memory newBalances = new uint256[](numTokens);

        // Copy currentBalances to newBalances.
        for (uint256 i = 0; i < numTokens; ++i) {
            newBalances[i] = currentBalances[i] - 1;
        }

        // Update the balance of tokenOutIndex with exactAmountOut.
        newBalances[tokenOutIndex] = newBalances[tokenOutIndex] - exactAmountOut;

        // Calculate the new invariant using the new balances (after the removal).
        // Calculate the new invariant ratio by dividing the new invariant by the old invariant.
        // Calculate the new proportional balance by multiplying the new invariant ratio by the current balance.
        // Calculate the taxable amount by subtracting the new balance from the equivalent proportional balance.
        // We round `currentInvariant` up as it affects the calculated `bptAmountIn` directly (see below).
        uint256 currentInvariant = pool.computeInvariant(currentBalances, Rounding.ROUND_UP);

        // We round invariant ratio up (see reason below).
        // This invariant ratio could be rounded up even more by rounding `currentInvariant` down. But since it only
        // affects the taxable amount and the fee calculation, whereas `currentInvariant` affects BPT in more directly,
        // we use `currentInvariant` rounded up here as well.
        uint256 invariantRatio = pool.computeInvariant(newBalances, Rounding.ROUND_UP).divUp(currentInvariant);

        ensureInvariantRatioAboveMinimumBound(pool, invariantRatio);

        // Taxable amount is proportional to invariant ratio; a larger taxable amount rounds in the Vault's favor.
        uint256 taxableAmount = invariantRatio.mulUp(currentBalances[tokenOutIndex]) - newBalances[tokenOutIndex];

        // Calculate the swap fee based on the taxable amount and the swap fee percentage.
        // Fee is proportional to taxable amount; larger fee rounds in the Vault's favor.
        uint256 fee = taxableAmount.divUp(swapFeePercentage.complement()) - taxableAmount;

        // Update new balances array with a fee.
        newBalances[tokenOutIndex] = newBalances[tokenOutIndex] - fee;

        // Calculate the new invariant with fees applied.
        // Larger fee means `invariantWithFeesApplied` goes lower.
        uint256 invariantWithFeesApplied = pool.computeInvariant(newBalances, Rounding.ROUND_DOWN);

        // Create swap fees amount array and set the single fee we charge.
        swapFeeAmounts = new uint256[](numTokens);
        swapFeeAmounts[tokenOutIndex] = fee;

        // Calculate the amount of BPT to burn. This is done by multiplying the total supply by the ratio of the
        // invariant delta to the current invariant.
        //
        // Calculating BPT amount in, so we round up. This is the most important result of this function, equivalent to:
        // `totalSupply * (1 - invariantWithFeesApplied / currentInvariant)`.
        // Then, to round `bptAmountIn` up we use `invariantWithFeesApplied` rounded down and `currentInvariant`
        // rounded up.
        //
        // Since `currentInvariant` is rounded up and `invariantWithFeesApplied` is rounded down, the difference
        // should always be positive. The checked math will revert if that is not the case.
        bptAmountIn = totalSupply.mulDivUp(currentInvariant - invariantWithFeesApplied, currentInvariant);
    }

    /**
     * @notice Computes the amount of a single token to withdraw for a given amount of BPT to burn.
     * @dev It computes the output token amount for an exact input of BPT, considering current balances,
     * total supply, and swap fees.
     *
     * @param currentBalances The current token balances in the pool
     * @param tokenOutIndex The index of the token to be withdrawn
     * @param exactBptAmountIn The exact amount of BPT the user wants to burn
     * @param totalSupply The current total supply of the pool tokens (BPT)
     * @param swapFeePercentage The swap fee percentage applied to the taxable amount
     * @param pool The pool from which we're removing liquidity
     * @return amountOutWithFee The amount of the output token the user receives, accounting for swap fees
     * @return swapFeeAmounts The total amount of swap fees charged
     */
    function computeRemoveLiquiditySingleTokenExactIn(
        uint256[] memory currentBalances,
        uint256 tokenOutIndex,
        uint256 exactBptAmountIn,
        uint256 totalSupply,
        uint256 swapFeePercentage,
        IBasePool pool
    ) internal view returns (uint256 amountOutWithFee, uint256[] memory swapFeeAmounts) {
        // Calculate new supply accounting for burning exactBptAmountIn.
        uint256 newSupply = totalSupply - exactBptAmountIn;
        uint256 invariantRatio = newSupply.divUp(totalSupply);
        ensureInvariantRatioAboveMinimumBound(pool, invariantRatio);

        // Calculate the new balance of the output token after the BPT burn.
        // "divUp" leads to a higher "newBalance", which in turn results in a lower "amountOut", but also a lower
        // "taxableAmount". Although the former leads to giving less tokens for the same amount of BPT burned,
        // the latter leads to charging less swap fees. In consequence, a conflict of interests arises regarding
        // the rounding of "newBalance"; we prioritize getting a lower "amountOut".
        uint256 newBalance = pool.computeBalance(currentBalances, tokenOutIndex, invariantRatio);

        // Compute the amount to be withdrawn from the pool.
        uint256 amountOut = currentBalances[tokenOutIndex] - newBalance;

        // Calculate the new balance proportionate to the amount of BPT burned.
        // We round up: higher `newBalanceBeforeTax` makes `taxableAmount` go up, which rounds in the Vault's favor.
        uint256 newBalanceBeforeTax = newSupply.mulDivUp(currentBalances[tokenOutIndex], totalSupply);

        // Compute the taxable amount: the difference between the new proportional and disproportional balances.
        uint256 taxableAmount = newBalanceBeforeTax - newBalance;

        // Calculate the swap fee on the taxable amount.
        uint256 fee = taxableAmount.mulUp(swapFeePercentage);

        // Create swap fees amount array and set the single fee we charge.
        swapFeeAmounts = new uint256[](currentBalances.length);
        swapFeeAmounts[tokenOutIndex] = fee;

        // Return the net amount after subtracting the fee.
        amountOutWithFee = amountOut - fee;
    }

    /**
     * @notice Validate the invariant ratio against the maximum bound.
     * @dev This is checked when we're adding liquidity, so the `invariantRatio` > 1.
     * @param pool The pool to which we're adding liquidity
     * @param invariantRatio The ratio of the new invariant (after an operation) to the old
     */
    function ensureInvariantRatioBelowMaximumBound(IBasePool pool, uint256 invariantRatio) internal view {
        uint256 maxInvariantRatio = pool.getMaximumInvariantRatio();
        if (invariantRatio > maxInvariantRatio) {
            revert InvariantRatioAboveMax(invariantRatio, maxInvariantRatio);
        }
    }

    /**
     * @notice Validate the invariant ratio against the maximum bound.
     * @dev This is checked when we're removing liquidity, so the `invariantRatio` < 1.
     * @param pool The pool from which we're removing liquidity
     * @param invariantRatio The ratio of the new invariant (after an operation) to the old
     */
    function ensureInvariantRatioAboveMinimumBound(IBasePool pool, uint256 invariantRatio) internal view {
        uint256 minInvariantRatio = pool.getMinimumInvariantRatio();
        if (invariantRatio < minInvariantRatio) {
            revert InvariantRatioBelowMin(invariantRatio, minInvariantRatio);
        }
    }
}


// File: contracts/lib/HooksConfigLib.sol

// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.24;

import { IVaultErrors } from "@balancer-labs/v3-interfaces/contracts/vault/IVaultErrors.sol";
import { IHooks } from "@balancer-labs/v3-interfaces/contracts/vault/IHooks.sol";
import "@balancer-labs/v3-interfaces/contracts/vault/VaultTypes.sol";

import { WordCodec } from "@balancer-labs/v3-solidity-utils/contracts/helpers/WordCodec.sol";

import { PoolConfigConst } from "./PoolConfigConst.sol";

/**
 * @notice Helper functions to read and write the packed hook configuration flags stored in `_poolConfigBits`.
 * @dev This library has two additional functions. `toHooksConfig` constructs a `HooksConfig` structure from the
 * PoolConfig and the hooks contract address. Also, there are `call<hook>` functions that forward the arguments
 * to the corresponding functions in the hook contract, then validate and return the results.
 *
 * Note that the entire configuration of each pool is stored in the `_poolConfigBits` mapping (one slot per pool).
 * This includes the data in the `PoolConfig` struct, plus the data in the `HookFlags` struct. The layout (i.e.,
 * offsets for each data field) is specified in `PoolConfigConst`.
 *
 * There are two libraries for interpreting these data. This one parses fields related to hooks, and also
 * contains helpers for the struct building and hooks contract forwarding functions described above. `PoolConfigLib`
 * contains helpers related to the non-hook-related flags, along with aggregate fee percentages and other data
 * associated with pools.
 *
 * The `PoolData` struct contains the raw bitmap with the entire pool state (`PoolConfigBits`), plus the token
 * configuration, scaling factors, and dynamic information such as current balances and rates.
 *
 * The hooks contract addresses themselves are stored in a separate `_hooksContracts` mapping.
 */
library HooksConfigLib {
    using WordCodec for bytes32;
    using HooksConfigLib for PoolConfigBits;

    function enableHookAdjustedAmounts(PoolConfigBits config) internal pure returns (bool) {
        return PoolConfigBits.unwrap(config).decodeBool(PoolConfigConst.ENABLE_HOOK_ADJUSTED_AMOUNTS_OFFSET);
    }

    function setHookAdjustedAmounts(PoolConfigBits config, bool value) internal pure returns (PoolConfigBits) {
        return
            PoolConfigBits.wrap(
                PoolConfigBits.unwrap(config).insertBool(value, PoolConfigConst.ENABLE_HOOK_ADJUSTED_AMOUNTS_OFFSET)
            );
    }

    function shouldCallBeforeInitialize(PoolConfigBits config) internal pure returns (bool) {
        return PoolConfigBits.unwrap(config).decodeBool(PoolConfigConst.BEFORE_INITIALIZE_OFFSET);
    }

    function setShouldCallBeforeInitialize(PoolConfigBits config, bool value) internal pure returns (PoolConfigBits) {
        return
            PoolConfigBits.wrap(
                PoolConfigBits.unwrap(config).insertBool(value, PoolConfigConst.BEFORE_INITIALIZE_OFFSET)
            );
    }

    function shouldCallAfterInitialize(PoolConfigBits config) internal pure returns (bool) {
        return PoolConfigBits.unwrap(config).decodeBool(PoolConfigConst.AFTER_INITIALIZE_OFFSET);
    }

    function setShouldCallAfterInitialize(PoolConfigBits config, bool value) internal pure returns (PoolConfigBits) {
        return
            PoolConfigBits.wrap(
                PoolConfigBits.unwrap(config).insertBool(value, PoolConfigConst.AFTER_INITIALIZE_OFFSET)
            );
    }

    function shouldCallComputeDynamicSwapFee(PoolConfigBits config) internal pure returns (bool) {
        return PoolConfigBits.unwrap(config).decodeBool(PoolConfigConst.DYNAMIC_SWAP_FEE_OFFSET);
    }

    function setShouldCallComputeDynamicSwapFee(
        PoolConfigBits config,
        bool value
    ) internal pure returns (PoolConfigBits) {
        return
            PoolConfigBits.wrap(
                PoolConfigBits.unwrap(config).insertBool(value, PoolConfigConst.DYNAMIC_SWAP_FEE_OFFSET)
            );
    }

    function shouldCallBeforeSwap(PoolConfigBits config) internal pure returns (bool) {
        return PoolConfigBits.unwrap(config).decodeBool(PoolConfigConst.BEFORE_SWAP_OFFSET);
    }

    function setShouldCallBeforeSwap(PoolConfigBits config, bool value) internal pure returns (PoolConfigBits) {
        return PoolConfigBits.wrap(PoolConfigBits.unwrap(config).insertBool(value, PoolConfigConst.BEFORE_SWAP_OFFSET));
    }

    function shouldCallAfterSwap(PoolConfigBits config) internal pure returns (bool) {
        return PoolConfigBits.unwrap(config).decodeBool(PoolConfigConst.AFTER_SWAP_OFFSET);
    }

    function setShouldCallAfterSwap(PoolConfigBits config, bool value) internal pure returns (PoolConfigBits) {
        return PoolConfigBits.wrap(PoolConfigBits.unwrap(config).insertBool(value, PoolConfigConst.AFTER_SWAP_OFFSET));
    }

    function shouldCallBeforeAddLiquidity(PoolConfigBits config) internal pure returns (bool) {
        return PoolConfigBits.unwrap(config).decodeBool(PoolConfigConst.BEFORE_ADD_LIQUIDITY_OFFSET);
    }

    function setShouldCallBeforeAddLiquidity(PoolConfigBits config, bool value) internal pure returns (PoolConfigBits) {
        return
            PoolConfigBits.wrap(
                PoolConfigBits.unwrap(config).insertBool(value, PoolConfigConst.BEFORE_ADD_LIQUIDITY_OFFSET)
            );
    }

    function shouldCallAfterAddLiquidity(PoolConfigBits config) internal pure returns (bool) {
        return PoolConfigBits.unwrap(config).decodeBool(PoolConfigConst.AFTER_ADD_LIQUIDITY_OFFSET);
    }

    function setShouldCallAfterAddLiquidity(PoolConfigBits config, bool value) internal pure returns (PoolConfigBits) {
        return
            PoolConfigBits.wrap(
                PoolConfigBits.unwrap(config).insertBool(value, PoolConfigConst.AFTER_ADD_LIQUIDITY_OFFSET)
            );
    }

    function shouldCallBeforeRemoveLiquidity(PoolConfigBits config) internal pure returns (bool) {
        return PoolConfigBits.unwrap(config).decodeBool(PoolConfigConst.BEFORE_REMOVE_LIQUIDITY_OFFSET);
    }

    function setShouldCallBeforeRemoveLiquidity(
        PoolConfigBits config,
        bool value
    ) internal pure returns (PoolConfigBits) {
        return
            PoolConfigBits.wrap(
                PoolConfigBits.unwrap(config).insertBool(value, PoolConfigConst.BEFORE_REMOVE_LIQUIDITY_OFFSET)
            );
    }

    function shouldCallAfterRemoveLiquidity(PoolConfigBits config) internal pure returns (bool) {
        return PoolConfigBits.unwrap(config).decodeBool(PoolConfigConst.AFTER_REMOVE_LIQUIDITY_OFFSET);
    }

    function setShouldCallAfterRemoveLiquidity(
        PoolConfigBits config,
        bool value
    ) internal pure returns (PoolConfigBits) {
        return
            PoolConfigBits.wrap(
                PoolConfigBits.unwrap(config).insertBool(value, PoolConfigConst.AFTER_REMOVE_LIQUIDITY_OFFSET)
            );
    }

    function toHooksConfig(PoolConfigBits config, IHooks hooksContract) internal pure returns (HooksConfig memory) {
        return
            HooksConfig({
                enableHookAdjustedAmounts: config.enableHookAdjustedAmounts(),
                shouldCallBeforeInitialize: config.shouldCallBeforeInitialize(),
                shouldCallAfterInitialize: config.shouldCallAfterInitialize(),
                shouldCallBeforeAddLiquidity: config.shouldCallBeforeAddLiquidity(),
                shouldCallAfterAddLiquidity: config.shouldCallAfterAddLiquidity(),
                shouldCallBeforeRemoveLiquidity: config.shouldCallBeforeRemoveLiquidity(),
                shouldCallAfterRemoveLiquidity: config.shouldCallAfterRemoveLiquidity(),
                shouldCallComputeDynamicSwapFee: config.shouldCallComputeDynamicSwapFee(),
                shouldCallBeforeSwap: config.shouldCallBeforeSwap(),
                shouldCallAfterSwap: config.shouldCallAfterSwap(),
                hooksContract: address(hooksContract)
            });
    }

    /**
     * @dev Call the `onComputeDynamicSwapFeePercentage` hook and return the result. Reverts on failure.
     * @param swapParams The swap parameters used to calculate the fee
     * @param pool Pool address
     * @param staticSwapFeePercentage Value of the static swap fee, for reference
     * @param hooksContract Storage slot with the address of the hooks contract
     * @return swapFeePercentage The calculated swap fee percentage
     */
    function callComputeDynamicSwapFeeHook(
        PoolSwapParams memory swapParams,
        address pool,
        uint256 staticSwapFeePercentage,
        IHooks hooksContract
    ) internal view returns (uint256) {
        (bool success, uint256 swapFeePercentage) = hooksContract.onComputeDynamicSwapFeePercentage(
            swapParams,
            pool,
            staticSwapFeePercentage
        );

        if (success == false) {
            revert IVaultErrors.DynamicSwapFeeHookFailed();
        }

        // A 100% fee is not supported. In the ExactOut case, the Vault divides by the complement of the swap fee.
        // The minimum precision constraint provides an additional buffer.
        if (swapFeePercentage > MAX_FEE_PERCENTAGE) {
            revert IVaultErrors.PercentageAboveMax();
        }

        return swapFeePercentage;
    }

    /**
     * @dev Call the `onBeforeSwap` hook. Reverts on failure.
     * @param swapParams The swap parameters used in the hook
     * @param pool Pool address
     * @param hooksContract Storage slot with the address of the hooks contract
     */
    function callBeforeSwapHook(PoolSwapParams memory swapParams, address pool, IHooks hooksContract) internal {
        if (hooksContract.onBeforeSwap(swapParams, pool) == false) {
            // Hook contract implements onBeforeSwap, but it has failed, so reverts the transaction.
            revert IVaultErrors.BeforeSwapHookFailed();
        }
    }

    /**
     * @dev Call the `onAfterSwap` hook, then validate and return the result. Reverts on failure, or if the limits
     * are violated. If the hook contract did not enable hook-adjusted amounts, it will ignore the hook results and
     * return the original `amountCalculatedRaw`.
     *
     * @param config The encoded pool configuration
     * @param amountCalculatedScaled18 Token amount calculated by the swap
     * @param amountCalculatedRaw Token amount calculated by the swap
     * @param router Router address
     * @param vaultSwapParams The swap parameters
     * @param state Temporary state used in swap operations
     * @param poolData Struct containing balance and token information of the pool
     * @param hooksContract Storage slot with the address of the hooks contract
     * @return hookAdjustedAmountCalculatedRaw New amount calculated, potentially modified by the hook
     */
    function callAfterSwapHook(
        PoolConfigBits config,
        uint256 amountCalculatedScaled18,
        uint256 amountCalculatedRaw,
        address router,
        VaultSwapParams memory vaultSwapParams,
        SwapState memory state,
        PoolData memory poolData,
        IHooks hooksContract
    ) internal returns (uint256) {
        // Adjust balances for the AfterSwap hook.
        (uint256 amountInScaled18, uint256 amountOutScaled18) = vaultSwapParams.kind == SwapKind.EXACT_IN
            ? (state.amountGivenScaled18, amountCalculatedScaled18)
            : (amountCalculatedScaled18, state.amountGivenScaled18);

        (bool success, uint256 hookAdjustedAmountCalculatedRaw) = hooksContract.onAfterSwap(
            AfterSwapParams({
                kind: vaultSwapParams.kind,
                tokenIn: vaultSwapParams.tokenIn,
                tokenOut: vaultSwapParams.tokenOut,
                amountInScaled18: amountInScaled18,
                amountOutScaled18: amountOutScaled18,
                tokenInBalanceScaled18: poolData.balancesLiveScaled18[state.indexIn],
                tokenOutBalanceScaled18: poolData.balancesLiveScaled18[state.indexOut],
                amountCalculatedScaled18: amountCalculatedScaled18,
                amountCalculatedRaw: amountCalculatedRaw,
                router: router,
                pool: vaultSwapParams.pool,
                userData: vaultSwapParams.userData
            })
        );

        if (success == false) {
            // Hook contract implements onAfterSwap, but it has failed, so reverts the transaction.
            revert IVaultErrors.AfterSwapHookFailed();
        }

        // If hook adjusted amounts is not enabled, ignore amounts returned by the hook
        if (config.enableHookAdjustedAmounts() == false) {
            return amountCalculatedRaw;
        }

        if (
            (vaultSwapParams.kind == SwapKind.EXACT_IN && hookAdjustedAmountCalculatedRaw < vaultSwapParams.limitRaw) ||
            (vaultSwapParams.kind == SwapKind.EXACT_OUT && hookAdjustedAmountCalculatedRaw > vaultSwapParams.limitRaw)
        ) {
            revert IVaultErrors.HookAdjustedSwapLimit(hookAdjustedAmountCalculatedRaw, vaultSwapParams.limitRaw);
        }

        return hookAdjustedAmountCalculatedRaw;
    }

    /**
     * @dev Call the `onBeforeAddLiquidity` hook. Reverts on failure.
     * @param router Router address
     * @param maxAmountsInScaled18 An array with maximum amounts for each input token of the add liquidity operation
     * @param params The add liquidity parameters
     * @param poolData Struct containing balance and token information of the pool
     * @param hooksContract Storage slot with the address of the hooks contract
     */
    function callBeforeAddLiquidityHook(
        address router,
        uint256[] memory maxAmountsInScaled18,
        AddLiquidityParams memory params,
        PoolData memory poolData,
        IHooks hooksContract
    ) internal {
        if (
            hooksContract.onBeforeAddLiquidity(
                router,
                params.pool,
                params.kind,
                maxAmountsInScaled18,
                params.minBptAmountOut,
                poolData.balancesLiveScaled18,
                params.userData
            ) == false
        ) {
            revert IVaultErrors.BeforeAddLiquidityHookFailed();
        }
    }

    /**
     * @dev Call the `onAfterAddLiquidity` hook, then validate and return the result. Reverts on failure, or if
     * the limits are violated. If the contract did not enable hook-adjusted amounts, it will ignore the hook
     * results and return the original `amountsInRaw`.
     *
     * @param config The encoded pool configuration
     * @param router Router address
     * @param amountsInScaled18 An array with amounts for each input token of the add liquidity operation
     * @param amountsInRaw An array with amounts for each input token of the add liquidity operation
     * @param bptAmountOut The BPT amount a user will receive after add liquidity operation succeeds
     * @param params The add liquidity parameters
     * @param poolData Struct containing balance and token information of the pool
     * @param hooksContract Storage slot with the address of the hooks contract
     * @return hookAdjustedAmountsInRaw New amountsInRaw, potentially modified by the hook
     */
    function callAfterAddLiquidityHook(
        PoolConfigBits config,
        address router,
        uint256[] memory amountsInScaled18,
        uint256[] memory amountsInRaw,
        uint256 bptAmountOut,
        AddLiquidityParams memory params,
        PoolData memory poolData,
        IHooks hooksContract
    ) internal returns (uint256[] memory) {
        (bool success, uint256[] memory hookAdjustedAmountsInRaw) = hooksContract.onAfterAddLiquidity(
            router,
            params.pool,
            params.kind,
            amountsInScaled18,
            amountsInRaw,
            bptAmountOut,
            poolData.balancesLiveScaled18,
            params.userData
        );

        if (success == false || hookAdjustedAmountsInRaw.length != amountsInRaw.length) {
            revert IVaultErrors.AfterAddLiquidityHookFailed();
        }

        // If hook adjusted amounts is not enabled, ignore amounts returned by the hook
        if (config.enableHookAdjustedAmounts() == false) {
            return amountsInRaw;
        }

        for (uint256 i = 0; i < hookAdjustedAmountsInRaw.length; i++) {
            if (hookAdjustedAmountsInRaw[i] > params.maxAmountsIn[i]) {
                revert IVaultErrors.HookAdjustedAmountInAboveMax(
                    poolData.tokens[i],
                    hookAdjustedAmountsInRaw[i],
                    params.maxAmountsIn[i]
                );
            }
        }

        return hookAdjustedAmountsInRaw;
    }

    /**
     * @dev Call the `onBeforeRemoveLiquidity` hook. Reverts on failure.
     * @param minAmountsOutScaled18 Minimum amounts for each output token of the remove liquidity operation
     * @param router Router address
     * @param params The remove liquidity parameters
     * @param poolData Struct containing balance and token information of the pool
     * @param hooksContract Storage slot with the address of the hooks contract
     */
    function callBeforeRemoveLiquidityHook(
        uint256[] memory minAmountsOutScaled18,
        address router,
        RemoveLiquidityParams memory params,
        PoolData memory poolData,
        IHooks hooksContract
    ) internal {
        if (
            hooksContract.onBeforeRemoveLiquidity(
                router,
                params.pool,
                params.kind,
                params.maxBptAmountIn,
                minAmountsOutScaled18,
                poolData.balancesLiveScaled18,
                params.userData
            ) == false
        ) {
            revert IVaultErrors.BeforeRemoveLiquidityHookFailed();
        }
    }

    /**
     * @dev Call the `onAfterRemoveLiquidity` hook, then validate and return the result. Reverts on failure, or if
     * the limits are violated. If the contract did not enable hook-adjusted amounts, it will ignore the hook
     * results and return the original `amountsOutRaw`.
     *
     * @param config The encoded pool configuration
     * @param router Router address
     * @param amountsOutScaled18 Scaled amount of tokens to receive, sorted in token registration order
     * @param amountsOutRaw Actual amount of tokens to receive, sorted in token registration order
     * @param bptAmountIn The BPT amount a user will need burn to remove the liquidity of the pool
     * @param params The remove liquidity parameters
     * @param poolData Struct containing balance and token information of the pool
     * @param hooksContract Storage slot with the address of the hooks contract
     * @return hookAdjustedAmountsOutRaw New amountsOutRaw, potentially modified by the hook
     */
    function callAfterRemoveLiquidityHook(
        PoolConfigBits config,
        address router,
        uint256[] memory amountsOutScaled18,
        uint256[] memory amountsOutRaw,
        uint256 bptAmountIn,
        RemoveLiquidityParams memory params,
        PoolData memory poolData,
        IHooks hooksContract
    ) internal returns (uint256[] memory) {
        (bool success, uint256[] memory hookAdjustedAmountsOutRaw) = hooksContract.onAfterRemoveLiquidity(
            router,
            params.pool,
            params.kind,
            bptAmountIn,
            amountsOutScaled18,
            amountsOutRaw,
            poolData.balancesLiveScaled18,
            params.userData
        );

        if (success == false || hookAdjustedAmountsOutRaw.length != amountsOutRaw.length) {
            revert IVaultErrors.AfterRemoveLiquidityHookFailed();
        }

        // If hook adjusted amounts is not enabled, ignore amounts returned by the hook
        if (config.enableHookAdjustedAmounts() == false) {
            return amountsOutRaw;
        }

        for (uint256 i = 0; i < hookAdjustedAmountsOutRaw.length; i++) {
            if (hookAdjustedAmountsOutRaw[i] < params.minAmountsOut[i]) {
                revert IVaultErrors.HookAdjustedAmountOutBelowMin(
                    poolData.tokens[i],
                    hookAdjustedAmountsOutRaw[i],
                    params.minAmountsOut[i]
                );
            }
        }

        return hookAdjustedAmountsOutRaw;
    }

    /**
     * @dev Call the `onBeforeInitialize` hook. Reverts on failure.
     * @param exactAmountsInScaled18 An array with the initial liquidity of the pool
     * @param userData Additional (optional) data required for adding initial liquidity
     * @param hooksContract Storage slot with the address of the hooks contract
     */
    function callBeforeInitializeHook(
        uint256[] memory exactAmountsInScaled18,
        bytes memory userData,
        IHooks hooksContract
    ) internal {
        if (hooksContract.onBeforeInitialize(exactAmountsInScaled18, userData) == false) {
            revert IVaultErrors.BeforeInitializeHookFailed();
        }
    }

    /**
     * @dev Call the `onAfterInitialize` hook. Reverts on failure.
     * @param exactAmountsInScaled18 An array with the initial liquidity of the pool
     * @param bptAmountOut The BPT amount a user will receive after initialization operation succeeds
     * @param userData Additional (optional) data required for adding initial liquidity
     * @param hooksContract Storage slot with the address of the hooks contract
     */
    function callAfterInitializeHook(
        uint256[] memory exactAmountsInScaled18,
        uint256 bptAmountOut,
        bytes memory userData,
        IHooks hooksContract
    ) internal {
        if (hooksContract.onAfterInitialize(exactAmountsInScaled18, bptAmountOut, userData) == false) {
            revert IVaultErrors.AfterInitializeHookFailed();
        }
    }
}


// File: contracts/lib/PoolConfigConst.sol

// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.24;

import { FEE_BITLENGTH } from "@balancer-labs/v3-interfaces/contracts/vault/VaultTypes.sol";

/**
 * @notice Helper functions to read and write the packed configuration flags stored in `_poolConfigBits`.
 * @dev Note that the entire configuration of each pool is stored in the `_poolConfigBits` mapping (one slot per pool).
 * This includes the data in the `PoolConfig` struct, plus the data in the `HookFlags` struct. The layout (i.e.,
 * offsets for each data field) is specified here.
 *
 * There are two libraries for interpreting these data. `HooksConfigLib` parses fields related to hooks, while
 * `PoolConfigLib` contains helpers related to the non-hook-related flags, along with aggregate fee percentages
 * and other data associated with pools.
 */
library PoolConfigConst {
    // Bit offsets for main pool config settings.
    uint8 public constant POOL_REGISTERED_OFFSET = 0;
    uint8 public constant POOL_INITIALIZED_OFFSET = POOL_REGISTERED_OFFSET + 1;
    uint8 public constant POOL_PAUSED_OFFSET = POOL_INITIALIZED_OFFSET + 1;
    uint8 public constant POOL_RECOVERY_MODE_OFFSET = POOL_PAUSED_OFFSET + 1;

    // Bit offsets for liquidity operations.
    uint8 public constant UNBALANCED_LIQUIDITY_OFFSET = POOL_RECOVERY_MODE_OFFSET + 1;
    uint8 public constant ADD_LIQUIDITY_CUSTOM_OFFSET = UNBALANCED_LIQUIDITY_OFFSET + 1;
    uint8 public constant REMOVE_LIQUIDITY_CUSTOM_OFFSET = ADD_LIQUIDITY_CUSTOM_OFFSET + 1;
    uint8 public constant DONATION_OFFSET = REMOVE_LIQUIDITY_CUSTOM_OFFSET + 1;

    // Bit offsets for hooks config.
    uint8 public constant BEFORE_INITIALIZE_OFFSET = DONATION_OFFSET + 1;
    uint8 public constant ENABLE_HOOK_ADJUSTED_AMOUNTS_OFFSET = BEFORE_INITIALIZE_OFFSET + 1;
    uint8 public constant AFTER_INITIALIZE_OFFSET = ENABLE_HOOK_ADJUSTED_AMOUNTS_OFFSET + 1;
    uint8 public constant DYNAMIC_SWAP_FEE_OFFSET = AFTER_INITIALIZE_OFFSET + 1;
    uint8 public constant BEFORE_SWAP_OFFSET = DYNAMIC_SWAP_FEE_OFFSET + 1;
    uint8 public constant AFTER_SWAP_OFFSET = BEFORE_SWAP_OFFSET + 1;
    uint8 public constant BEFORE_ADD_LIQUIDITY_OFFSET = AFTER_SWAP_OFFSET + 1;
    uint8 public constant AFTER_ADD_LIQUIDITY_OFFSET = BEFORE_ADD_LIQUIDITY_OFFSET + 1;
    uint8 public constant BEFORE_REMOVE_LIQUIDITY_OFFSET = AFTER_ADD_LIQUIDITY_OFFSET + 1;
    uint8 public constant AFTER_REMOVE_LIQUIDITY_OFFSET = BEFORE_REMOVE_LIQUIDITY_OFFSET + 1;

    // Bit offsets for uint values.
    uint8 public constant STATIC_SWAP_FEE_OFFSET = AFTER_REMOVE_LIQUIDITY_OFFSET + 1;
    uint256 public constant AGGREGATE_SWAP_FEE_OFFSET = STATIC_SWAP_FEE_OFFSET + FEE_BITLENGTH;
    uint256 public constant AGGREGATE_YIELD_FEE_OFFSET = AGGREGATE_SWAP_FEE_OFFSET + FEE_BITLENGTH;
    uint256 public constant DECIMAL_SCALING_FACTORS_OFFSET = AGGREGATE_YIELD_FEE_OFFSET + FEE_BITLENGTH;
    uint256 public constant PAUSE_WINDOW_END_TIME_OFFSET =
        DECIMAL_SCALING_FACTORS_OFFSET + TOKEN_DECIMAL_DIFFS_BITLENGTH;

    // Uses a uint40 to pack the values: 8 tokens * 5 bits/token.
    // This maximum token count is also hard-coded in the Vault.
    uint8 public constant TOKEN_DECIMAL_DIFFS_BITLENGTH = 40;
    uint8 public constant DECIMAL_DIFF_BITLENGTH = 5;

    uint8 public constant TIMESTAMP_BITLENGTH = 32;
}


// File: contracts/lib/PoolConfigLib.sol

// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.24;

import { IVaultErrors } from "@balancer-labs/v3-interfaces/contracts/vault/IVaultErrors.sol";
import "@balancer-labs/v3-interfaces/contracts/vault/VaultTypes.sol";

import { WordCodec } from "@balancer-labs/v3-solidity-utils/contracts/helpers/WordCodec.sol";

import { PoolConfigConst } from "./PoolConfigConst.sol";

/**
 * @notice Helper functions to read and write the packed hook configuration flags stored in `_poolConfigBits`.
 * @dev  Note that the entire configuration of each pool is stored in the `_poolConfigBits` mapping (one slot
 * per pool). This includes the data in the `PoolConfig` struct, plus the data in the `HookFlags` struct.
 * The layout (i.e., offsets for each data field) is specified in `PoolConfigConst`.
 *
 * There are two libraries for interpreting these data. `HooksConfigLib` parses fields related to hooks, while
 * this one contains helpers related to the non-hook-related flags, along with aggregate fee percentages and
 * other data associated with pools.
 *
 * The `PoolData` struct contains the raw bitmap with the entire pool state (`PoolConfigBits`), plus the token
 * configuration, scaling factors, and dynamic information such as current balances and rates.
 */
library PoolConfigLib {
    using WordCodec for bytes32;
    using PoolConfigLib for PoolConfigBits;

    // Bit offsets for main pool config settings.
    function isPoolRegistered(PoolConfigBits config) internal pure returns (bool) {
        return PoolConfigBits.unwrap(config).decodeBool(PoolConfigConst.POOL_REGISTERED_OFFSET);
    }

    function setPoolRegistered(PoolConfigBits config, bool value) internal pure returns (PoolConfigBits) {
        return
            PoolConfigBits.wrap(
                PoolConfigBits.unwrap(config).insertBool(value, PoolConfigConst.POOL_REGISTERED_OFFSET)
            );
    }

    function isPoolInitialized(PoolConfigBits config) internal pure returns (bool) {
        return PoolConfigBits.unwrap(config).decodeBool(PoolConfigConst.POOL_INITIALIZED_OFFSET);
    }

    function setPoolInitialized(PoolConfigBits config, bool value) internal pure returns (PoolConfigBits) {
        return
            PoolConfigBits.wrap(
                PoolConfigBits.unwrap(config).insertBool(value, PoolConfigConst.POOL_INITIALIZED_OFFSET)
            );
    }

    function isPoolPaused(PoolConfigBits config) internal pure returns (bool) {
        return PoolConfigBits.unwrap(config).decodeBool(PoolConfigConst.POOL_PAUSED_OFFSET);
    }

    function setPoolPaused(PoolConfigBits config, bool value) internal pure returns (PoolConfigBits) {
        return PoolConfigBits.wrap(PoolConfigBits.unwrap(config).insertBool(value, PoolConfigConst.POOL_PAUSED_OFFSET));
    }

    function isPoolInRecoveryMode(PoolConfigBits config) internal pure returns (bool) {
        return PoolConfigBits.unwrap(config).decodeBool(PoolConfigConst.POOL_RECOVERY_MODE_OFFSET);
    }

    function setPoolInRecoveryMode(PoolConfigBits config, bool value) internal pure returns (PoolConfigBits) {
        return
            PoolConfigBits.wrap(
                PoolConfigBits.unwrap(config).insertBool(value, PoolConfigConst.POOL_RECOVERY_MODE_OFFSET)
            );
    }

    // Bit offsets for liquidity operations.
    function supportsUnbalancedLiquidity(PoolConfigBits config) internal pure returns (bool) {
        // NOTE: The unbalanced liquidity flag is default-on (false means it is supported).
        // This function returns the inverted value.
        return !PoolConfigBits.unwrap(config).decodeBool(PoolConfigConst.UNBALANCED_LIQUIDITY_OFFSET);
    }

    function requireUnbalancedLiquidityEnabled(PoolConfigBits config) internal pure {
        if (config.supportsUnbalancedLiquidity() == false) {
            revert IVaultErrors.DoesNotSupportUnbalancedLiquidity();
        }
    }

    function setDisableUnbalancedLiquidity(
        PoolConfigBits config,
        bool disableUnbalancedLiquidity
    ) internal pure returns (PoolConfigBits) {
        return
            PoolConfigBits.wrap(
                PoolConfigBits.unwrap(config).insertBool(
                    disableUnbalancedLiquidity,
                    PoolConfigConst.UNBALANCED_LIQUIDITY_OFFSET
                )
            );
    }

    function supportsAddLiquidityCustom(PoolConfigBits config) internal pure returns (bool) {
        return PoolConfigBits.unwrap(config).decodeBool(PoolConfigConst.ADD_LIQUIDITY_CUSTOM_OFFSET);
    }

    function requireAddLiquidityCustomEnabled(PoolConfigBits config) internal pure {
        if (config.supportsAddLiquidityCustom() == false) {
            revert IVaultErrors.DoesNotSupportAddLiquidityCustom();
        }
    }

    function setAddLiquidityCustom(
        PoolConfigBits config,
        bool enableAddLiquidityCustom
    ) internal pure returns (PoolConfigBits) {
        return
            PoolConfigBits.wrap(
                PoolConfigBits.unwrap(config).insertBool(
                    enableAddLiquidityCustom,
                    PoolConfigConst.ADD_LIQUIDITY_CUSTOM_OFFSET
                )
            );
    }

    function supportsRemoveLiquidityCustom(PoolConfigBits config) internal pure returns (bool) {
        return PoolConfigBits.unwrap(config).decodeBool(PoolConfigConst.REMOVE_LIQUIDITY_CUSTOM_OFFSET);
    }

    function requireRemoveLiquidityCustomEnabled(PoolConfigBits config) internal pure {
        if (config.supportsRemoveLiquidityCustom() == false) {
            revert IVaultErrors.DoesNotSupportRemoveLiquidityCustom();
        }
    }

    function setRemoveLiquidityCustom(
        PoolConfigBits config,
        bool enableRemoveLiquidityCustom
    ) internal pure returns (PoolConfigBits) {
        return
            PoolConfigBits.wrap(
                PoolConfigBits.unwrap(config).insertBool(
                    enableRemoveLiquidityCustom,
                    PoolConfigConst.REMOVE_LIQUIDITY_CUSTOM_OFFSET
                )
            );
    }

    function supportsDonation(PoolConfigBits config) internal pure returns (bool) {
        return PoolConfigBits.unwrap(config).decodeBool(PoolConfigConst.DONATION_OFFSET);
    }

    function setDonation(PoolConfigBits config, bool enableDonation) internal pure returns (PoolConfigBits) {
        return
            PoolConfigBits.wrap(
                PoolConfigBits.unwrap(config).insertBool(enableDonation, PoolConfigConst.DONATION_OFFSET)
            );
    }

    function requireDonationEnabled(PoolConfigBits config) internal pure {
        if (config.supportsDonation() == false) {
            revert IVaultErrors.DoesNotSupportDonation();
        }
    }

    // Bit offsets for uint values.
    function getStaticSwapFeePercentage(PoolConfigBits config) internal pure returns (uint256) {
        return
            PoolConfigBits.unwrap(config).decodeUint(PoolConfigConst.STATIC_SWAP_FEE_OFFSET, FEE_BITLENGTH) *
            FEE_SCALING_FACTOR;
    }

    function setStaticSwapFeePercentage(PoolConfigBits config, uint256 value) internal pure returns (PoolConfigBits) {
        // A 100% fee is not supported. In the ExactOut case, the Vault divides by the complement of the swap fee.
        // The max fee percentage is slightly below 100%.
        if (value > MAX_FEE_PERCENTAGE) {
            revert IVaultErrors.PercentageAboveMax();
        }
        value /= FEE_SCALING_FACTOR;

        return
            PoolConfigBits.wrap(
                PoolConfigBits.unwrap(config).insertUint(value, PoolConfigConst.STATIC_SWAP_FEE_OFFSET, FEE_BITLENGTH)
            );
    }

    function getAggregateSwapFeePercentage(PoolConfigBits config) internal pure returns (uint256) {
        return
            PoolConfigBits.unwrap(config).decodeUint(PoolConfigConst.AGGREGATE_SWAP_FEE_OFFSET, FEE_BITLENGTH) *
            FEE_SCALING_FACTOR;
    }

    function setAggregateSwapFeePercentage(
        PoolConfigBits config,
        uint256 value
    ) internal pure returns (PoolConfigBits) {
        if (value > MAX_FEE_PERCENTAGE) {
            revert IVaultErrors.PercentageAboveMax();
        }
        value /= FEE_SCALING_FACTOR;

        return
            PoolConfigBits.wrap(
                PoolConfigBits.unwrap(config).insertUint(
                    value,
                    PoolConfigConst.AGGREGATE_SWAP_FEE_OFFSET,
                    FEE_BITLENGTH
                )
            );
    }

    function getAggregateYieldFeePercentage(PoolConfigBits config) internal pure returns (uint256) {
        return
            PoolConfigBits.unwrap(config).decodeUint(PoolConfigConst.AGGREGATE_YIELD_FEE_OFFSET, FEE_BITLENGTH) *
            FEE_SCALING_FACTOR;
    }

    function setAggregateYieldFeePercentage(
        PoolConfigBits config,
        uint256 value
    ) internal pure returns (PoolConfigBits) {
        if (value > MAX_FEE_PERCENTAGE) {
            revert IVaultErrors.PercentageAboveMax();
        }
        value /= FEE_SCALING_FACTOR;

        return
            PoolConfigBits.wrap(
                PoolConfigBits.unwrap(config).insertUint(
                    value,
                    PoolConfigConst.AGGREGATE_YIELD_FEE_OFFSET,
                    FEE_BITLENGTH
                )
            );
    }

    function getTokenDecimalDiffs(PoolConfigBits config) internal pure returns (uint40) {
        return
            uint40(
                PoolConfigBits.unwrap(config).decodeUint(
                    PoolConfigConst.DECIMAL_SCALING_FACTORS_OFFSET,
                    PoolConfigConst.TOKEN_DECIMAL_DIFFS_BITLENGTH
                )
            );
    }

    function getDecimalScalingFactors(
        PoolConfigBits config,
        uint256 numTokens
    ) internal pure returns (uint256[] memory) {
        uint256[] memory scalingFactors = new uint256[](numTokens);

        bytes32 tokenDecimalDiffs = bytes32(uint256(config.getTokenDecimalDiffs()));

        for (uint256 i = 0; i < numTokens; ++i) {
            uint256 decimalDiff = tokenDecimalDiffs.decodeUint(
                i * PoolConfigConst.DECIMAL_DIFF_BITLENGTH,
                PoolConfigConst.DECIMAL_DIFF_BITLENGTH
            );

            // This is a "raw" factor, not a fixed point number. It should be applied using raw math to raw amounts
            // instead of using FP multiplication.
            scalingFactors[i] = 10 ** decimalDiff;
        }

        return scalingFactors;
    }

    function setTokenDecimalDiffs(PoolConfigBits config, uint40 value) internal pure returns (PoolConfigBits) {
        return
            PoolConfigBits.wrap(
                PoolConfigBits.unwrap(config).insertUint(
                    value,
                    PoolConfigConst.DECIMAL_SCALING_FACTORS_OFFSET,
                    PoolConfigConst.TOKEN_DECIMAL_DIFFS_BITLENGTH
                )
            );
    }

    function getPauseWindowEndTime(PoolConfigBits config) internal pure returns (uint32) {
        return
            uint32(
                PoolConfigBits.unwrap(config).decodeUint(
                    PoolConfigConst.PAUSE_WINDOW_END_TIME_OFFSET,
                    PoolConfigConst.TIMESTAMP_BITLENGTH
                )
            );
    }

    function setPauseWindowEndTime(PoolConfigBits config, uint32 value) internal pure returns (PoolConfigBits) {
        return
            PoolConfigBits.wrap(
                PoolConfigBits.unwrap(config).insertUint(
                    value,
                    PoolConfigConst.PAUSE_WINDOW_END_TIME_OFFSET,
                    PoolConfigConst.TIMESTAMP_BITLENGTH
                )
            );
    }

    // Convert from an array of decimal differences, to the encoded 40-bit value (8 tokens * 5 bits/token).
    function toTokenDecimalDiffs(uint8[] memory tokenDecimalDiffs) internal pure returns (uint40) {
        bytes32 value;

        for (uint256 i = 0; i < tokenDecimalDiffs.length; ++i) {
            value = value.insertUint(
                tokenDecimalDiffs[i],
                i * PoolConfigConst.DECIMAL_DIFF_BITLENGTH,
                PoolConfigConst.DECIMAL_DIFF_BITLENGTH
            );
        }

        return uint40(uint256(value));
    }
}


// File: contracts/lib/PoolDataLib.sol

// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.24;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { PoolData, TokenInfo, TokenType, Rounding } from "@balancer-labs/v3-interfaces/contracts/vault/VaultTypes.sol";
import { IVaultErrors } from "@balancer-labs/v3-interfaces/contracts/vault/IVaultErrors.sol";

import { FixedPoint } from "@balancer-labs/v3-solidity-utils/contracts/math/FixedPoint.sol";
import { ScalingHelpers } from "@balancer-labs/v3-solidity-utils/contracts/helpers/ScalingHelpers.sol";
import { PackedTokenBalance } from "@balancer-labs/v3-solidity-utils/contracts/helpers/PackedTokenBalance.sol";

import { PoolConfigBits, PoolConfigLib } from "./PoolConfigLib.sol";

/**
 * @notice Helper functions to read/write a `PoolData` struct.
 * @dev Note that the entire configuration of each pool is stored in the `_poolConfigBits` mapping (one slot per pool).
 * This includes the data in the `PoolConfig` struct, plus the data in the `HookFlags` struct. The layout (i.e.,
 * offsets for each data field) is specified in `PoolConfigConst`.
 *
 * The `PoolData` struct contains the raw bitmap with the entire pool state (`PoolConfigBits`), plus the token
 * configuration, scaling factors, and dynamic information such as current balances and rates.
 */
library PoolDataLib {
    using PackedTokenBalance for bytes32;
    using FixedPoint for *;
    using ScalingHelpers for *;
    using PoolConfigLib for PoolConfigBits;

    function load(
        PoolData memory poolData,
        mapping(uint256 tokenIndex => bytes32 packedTokenBalance) storage poolTokenBalances,
        PoolConfigBits poolConfigBits,
        mapping(IERC20 poolToken => TokenInfo tokenInfo) storage poolTokenInfo,
        IERC20[] storage tokens,
        Rounding roundingDirection
    ) internal view {
        uint256 numTokens = tokens.length;

        poolData.poolConfigBits = poolConfigBits;
        poolData.tokens = tokens;
        poolData.tokenInfo = new TokenInfo[](numTokens);
        poolData.balancesRaw = new uint256[](numTokens);
        poolData.balancesLiveScaled18 = new uint256[](numTokens);
        poolData.decimalScalingFactors = PoolConfigLib.getDecimalScalingFactors(poolData.poolConfigBits, numTokens);
        poolData.tokenRates = new uint256[](numTokens);

        bool poolSubjectToYieldFees = poolData.poolConfigBits.isPoolInitialized() &&
            poolData.poolConfigBits.getAggregateYieldFeePercentage() > 0 &&
            poolData.poolConfigBits.isPoolInRecoveryMode() == false;

        for (uint256 i = 0; i < numTokens; ++i) {
            TokenInfo memory tokenInfo = poolTokenInfo[poolData.tokens[i]];
            bytes32 packedBalance = poolTokenBalances[i];

            poolData.tokenInfo[i] = tokenInfo;
            poolData.tokenRates[i] = getTokenRate(tokenInfo);
            updateRawAndLiveBalance(poolData, i, packedBalance.getBalanceRaw(), roundingDirection);

            // If there are no yield fees, we can save gas by skipping to the next token now.
            if (poolSubjectToYieldFees == false) {
                continue;
            }

            // `poolData` already has live balances computed from raw balances according to the token rates and the
            // given rounding direction. Charging a yield fee changes the raw balance, in which case the safest and
            // most numerically precise way to adjust the live balance is to simply repeat the scaling (hence the
            // second call below).

            // The Vault actually guarantees that a token with paysYieldFees set is a WITH_RATE token, so technically
            // we could just check the flag, but we don't want to introduce that dependency for a slight gas savings.
            bool tokenSubjectToYieldFees = tokenInfo.paysYieldFees && tokenInfo.tokenType == TokenType.WITH_RATE;

            // Do not charge yield fees before the pool is initialized, or in recovery mode.
            if (tokenSubjectToYieldFees) {
                uint256 aggregateYieldFeePercentage = poolData.poolConfigBits.getAggregateYieldFeePercentage();
                uint256 balanceRaw = poolData.balancesRaw[i];

                uint256 aggregateYieldFeeAmountRaw = _computeYieldFeesDue(
                    poolData,
                    packedBalance.getBalanceDerived(),
                    i,
                    aggregateYieldFeePercentage
                );

                if (aggregateYieldFeeAmountRaw > 0) {
                    updateRawAndLiveBalance(poolData, i, balanceRaw - aggregateYieldFeeAmountRaw, roundingDirection);
                }
            }
        }
    }

    function syncPoolBalancesAndFees(
        PoolData memory poolData,
        mapping(uint256 tokenIndex => bytes32 packedTokenBalance) storage poolTokenBalances,
        mapping(IERC20 token => bytes32 packedFeeAmounts) storage poolAggregateProtocolFeeAmounts
    ) internal {
        uint256 numTokens = poolData.balancesRaw.length;

        for (uint256 i = 0; i < numTokens; ++i) {
            IERC20 token = poolData.tokens[i];
            bytes32 packedBalances = poolTokenBalances[i];
            uint256 storedBalanceRaw = packedBalances.getBalanceRaw();

            // `poolData` now has balances updated with yield fees.
            // If yield fees are not 0, then the stored balance is greater than the one in memory.
            if (storedBalanceRaw > poolData.balancesRaw[i]) {
                // Both Swap and Yield fees are stored together in a `PackedTokenBalance`.
                // We have designated "Derived" the derived half for Yield fee storage.
                bytes32 packedProtocolFeeAmounts = poolAggregateProtocolFeeAmounts[token];
                poolAggregateProtocolFeeAmounts[token] = packedProtocolFeeAmounts.setBalanceDerived(
                    packedProtocolFeeAmounts.getBalanceDerived() + (storedBalanceRaw - poolData.balancesRaw[i])
                );
            }

            poolTokenBalances[i] = PackedTokenBalance.toPackedBalance(
                poolData.balancesRaw[i],
                poolData.balancesLiveScaled18[i]
            );
        }
    }

    /**
     * @dev This is typically called after a reentrant callback (e.g., a "before" liquidity operation callback),
     * to refresh the poolData struct with any balances (or rates) that might have changed.
     *
     * Preconditions: tokenConfig, balancesRaw, and decimalScalingFactors must be current in `poolData`.
     * Side effects: mutates tokenRates, balancesLiveScaled18 in `poolData`.
     */
    function reloadBalancesAndRates(
        PoolData memory poolData,
        mapping(uint256 tokenIndex => bytes32 packedTokenBalance) storage poolTokenBalances,
        Rounding roundingDirection
    ) internal view {
        uint256 numTokens = poolData.tokens.length;

        // It's possible a reentrant hook changed the raw balances in Vault storage.
        // Update them before computing the live balances.
        bytes32 packedBalance;

        for (uint256 i = 0; i < numTokens; ++i) {
            poolData.tokenRates[i] = getTokenRate(poolData.tokenInfo[i]);

            packedBalance = poolTokenBalances[i];

            // Note the order dependency. This requires up-to-date tokenRate for the token at index `i` in `poolData`.
            updateRawAndLiveBalance(poolData, i, packedBalance.getBalanceRaw(), roundingDirection);
        }
    }

    function getTokenRate(TokenInfo memory tokenInfo) internal view returns (uint256 rate) {
        TokenType tokenType = tokenInfo.tokenType;

        if (tokenType == TokenType.STANDARD) {
            rate = FixedPoint.ONE;
        } else if (tokenType == TokenType.WITH_RATE) {
            rate = tokenInfo.rateProvider.getRate();
        } else {
            revert IVaultErrors.InvalidTokenConfiguration();
        }
    }

    function updateRawAndLiveBalance(
        PoolData memory poolData,
        uint256 tokenIndex,
        uint256 newRawBalance,
        Rounding roundingDirection
    ) internal pure {
        poolData.balancesRaw[tokenIndex] = newRawBalance;

        function(uint256, uint256, uint256) internal pure returns (uint256) _upOrDown = roundingDirection ==
            Rounding.ROUND_UP
            ? ScalingHelpers.toScaled18ApplyRateRoundUp
            : ScalingHelpers.toScaled18ApplyRateRoundDown;

        poolData.balancesLiveScaled18[tokenIndex] = _upOrDown(
            newRawBalance,
            poolData.decimalScalingFactors[tokenIndex],
            poolData.tokenRates[tokenIndex]
        );
    }

    // solhint-disable-next-line private-vars-leading-underscore
    function _computeYieldFeesDue(
        PoolData memory poolData,
        uint256 lastLiveBalance,
        uint256 tokenIndex,
        uint256 aggregateYieldFeePercentage
    ) internal pure returns (uint256 aggregateYieldFeeAmountRaw) {
        uint256 currentLiveBalance = poolData.balancesLiveScaled18[tokenIndex];

        // Do not charge fees if rates go down. If the rate were to go up, down, and back up again, protocol fees
        // would be charged multiple times on the "same" yield. For tokens subject to yield fees, this should not
        // happen, or at least be very rare. It can be addressed for known volatile rates by setting the yield fee
        // exempt flag on registration, or compensated off-chain if there is an incident with a normally
        // well-behaved rate provider.
        if (currentLiveBalance > lastLiveBalance) {
            unchecked {
                // Magnitudes are checked above, so it's safe to do unchecked math here.
                uint256 aggregateYieldFeeAmountScaled18 = (currentLiveBalance - lastLiveBalance).mulUp(
                    aggregateYieldFeePercentage
                );

                // A pool is subject to yield fees if poolSubjectToYieldFees is true, meaning that
                // `protocolYieldFeePercentage > 0`. So, we don't need to check this again in here, saving some gas.
                aggregateYieldFeeAmountRaw = aggregateYieldFeeAmountScaled18.toRawUndoRateRoundDown(
                    poolData.decimalScalingFactors[tokenIndex],
                    poolData.tokenRates[tokenIndex]
                );
            }
        }
    }
}


// File: contracts/lib/VaultStateLib.sol

// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.24;

import { WordCodec } from "@balancer-labs/v3-solidity-utils/contracts/helpers/WordCodec.sol";

// @notice Custom type to store the Vault configuration.
type VaultStateBits is bytes32;

/// @notice Helper functions for reading and writing the `VaultState` struct.
library VaultStateLib {
    using WordCodec for bytes32;

    // Bit offsets for the Vault state flags.
    uint256 public constant QUERY_DISABLED_OFFSET = 0;
    uint256 public constant VAULT_PAUSED_OFFSET = QUERY_DISABLED_OFFSET + 1;
    uint256 public constant BUFFER_PAUSED_OFFSET = VAULT_PAUSED_OFFSET + 1;

    function isQueryDisabled(VaultStateBits config) internal pure returns (bool) {
        return VaultStateBits.unwrap(config).decodeBool(QUERY_DISABLED_OFFSET);
    }

    function setQueryDisabled(VaultStateBits config, bool value) internal pure returns (VaultStateBits) {
        return VaultStateBits.wrap(VaultStateBits.unwrap(config).insertBool(value, QUERY_DISABLED_OFFSET));
    }

    function isVaultPaused(VaultStateBits config) internal pure returns (bool) {
        return VaultStateBits.unwrap(config).decodeBool(VAULT_PAUSED_OFFSET);
    }

    function setVaultPaused(VaultStateBits config, bool value) internal pure returns (VaultStateBits) {
        return VaultStateBits.wrap(VaultStateBits.unwrap(config).insertBool(value, VAULT_PAUSED_OFFSET));
    }

    function areBuffersPaused(VaultStateBits config) internal pure returns (bool) {
        return VaultStateBits.unwrap(config).decodeBool(BUFFER_PAUSED_OFFSET);
    }

    function setBuffersPaused(VaultStateBits config, bool value) internal pure returns (VaultStateBits) {
        return VaultStateBits.wrap(VaultStateBits.unwrap(config).insertBool(value, BUFFER_PAUSED_OFFSET));
    }
}


// File: contracts/token/ERC20MultiToken.sol

// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.24;

import { IERC20Errors } from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

import { IERC20MultiTokenErrors } from "@balancer-labs/v3-interfaces/contracts/vault/IERC20MultiTokenErrors.sol";

import { EVMCallModeHelpers } from "@balancer-labs/v3-solidity-utils/contracts/helpers/EVMCallModeHelpers.sol";

import { BalancerPoolToken } from "../BalancerPoolToken.sol";

/**
 * @notice Store Token data and handle accounting for pool tokens in the Vault.
 * @dev The ERC20MultiToken is an ERC20-focused multi-token implementation that is fully compatible with the ERC20 API
 * on the token side. It also allows for the minting and burning of tokens on the multi-token side.
 */
abstract contract ERC20MultiToken is IERC20Errors, IERC20MultiTokenErrors {
    // Minimum total supply amount.
    uint256 internal constant _POOL_MINIMUM_TOTAL_SUPPLY = 1e6;

    /**
     * @notice Pool tokens are moved from one account (`from`) to another (`to`). Note that `value` may be zero.
     * @param pool The pool token being transferred
     * @param from The token source
     * @param to The token destination
     * @param value The number of tokens
     */
    event Transfer(address indexed pool, address indexed from, address indexed to, uint256 value);

    /**
     * @notice The allowance of a `spender` for an `owner` is set by a call to {approve}. `value` is the new allowance.
     * @param pool The pool token receiving the allowance
     * @param owner The token holder
     * @param spender The account being authorized to spend a given amount of the token
     * @param value The number of tokens spender is authorized to transfer from owner
     */
    event Approval(address indexed pool, address indexed owner, address indexed spender, uint256 value);

    // Users' pool token (BPT) balances.
    mapping(address token => mapping(address owner => uint256 balance)) private _balances;

    // Users' pool token (BPT) allowances.
    mapping(address token => mapping(address owner => mapping(address spender => uint256 allowance)))
        private _allowances;

    // Total supply of all pool tokens (BPT). These are tokens minted and burned by the Vault.
    // The Vault balances of regular pool tokens are stored in `_reservesOf`.
    mapping(address token => uint256 totalSupply) private _totalSupplyOf;

    function _totalSupply(address pool) internal view returns (uint256) {
        return _totalSupplyOf[pool];
    }

    function _balanceOf(address pool, address account) internal view returns (uint256) {
        return _balances[pool][account];
    }

    function _allowance(address pool, address owner, address spender) internal view returns (uint256) {
        // Owner can spend anything without approval
        if (owner == spender) {
            return type(uint256).max;
        } else {
            return _allowances[pool][owner][spender];
        }
    }

    /**
     * @dev DO NOT CALL THIS METHOD!
     * Only `removeLiquidity` in the Vault may call this - in a query context - to allow burning tokens the caller
     * does not have.
     */
    function _queryModeBalanceIncrease(address pool, address to, uint256 amount) internal {
        // Enforce that this can only be called in a read-only, query context.
        if (EVMCallModeHelpers.isStaticCall() == false) {
            revert EVMCallModeHelpers.NotStaticCall();
        }

        // Increase `to` balance to ensure the burn function succeeds during query.
        _balances[address(pool)][to] += amount;
    }

    function _mint(address pool, address to, uint256 amount) internal {
        if (to == address(0)) {
            revert ERC20InvalidReceiver(to);
        }

        uint256 newTotalSupply = _totalSupplyOf[pool] + amount;
        unchecked {
            // Overflow is not possible. balance + amount is at most totalSupply + amount, which is checked above.
            _balances[pool][to] += amount;
        }

        _ensurePoolMinimumTotalSupply(newTotalSupply);

        _totalSupplyOf[pool] = newTotalSupply;

        emit Transfer(pool, address(0), to, amount);

        // We also emit the "transfer" event on the pool token to ensure full compliance with the ERC20 standard.
        BalancerPoolToken(pool).emitTransfer(address(0), to, amount);
    }

    function _ensurePoolMinimumTotalSupply(uint256 newTotalSupply) internal pure {
        if (newTotalSupply < _POOL_MINIMUM_TOTAL_SUPPLY) {
            revert PoolTotalSupplyTooLow(newTotalSupply);
        }
    }

    function _mintMinimumSupplyReserve(address pool) internal {
        _totalSupplyOf[pool] += _POOL_MINIMUM_TOTAL_SUPPLY;
        unchecked {
            // Overflow is not possible. balance + amount is at most totalSupply + amount, which is checked above.
            _balances[pool][address(0)] += _POOL_MINIMUM_TOTAL_SUPPLY;
        }
        emit Transfer(pool, address(0), address(0), _POOL_MINIMUM_TOTAL_SUPPLY);

        // We also emit the "transfer" event on the pool token to ensure full compliance with the ERC20 standard.
        BalancerPoolToken(pool).emitTransfer(address(0), address(0), _POOL_MINIMUM_TOTAL_SUPPLY);
    }

    function _burn(address pool, address from, uint256 amount) internal {
        if (from == address(0)) {
            revert ERC20InvalidSender(from);
        }

        uint256 accountBalance = _balances[pool][from];
        if (amount > accountBalance) {
            revert ERC20InsufficientBalance(from, accountBalance, amount);
        }

        unchecked {
            _balances[pool][from] = accountBalance - amount;
        }
        uint256 newTotalSupply = _totalSupplyOf[pool] - amount;

        _ensurePoolMinimumTotalSupply(newTotalSupply);

        _totalSupplyOf[pool] = newTotalSupply;

        // We also emit the "transfer" event on the pool token to ensure full compliance with the ERC20 standard.
        // If this function fails we keep going, as this is used in recovery mode.
        // Well-behaved pools will just emit an event here, so they should never fail.
        try BalancerPoolToken(pool).emitTransfer(from, address(0), amount) {} catch {
            // solhint-disable-previous-line no-empty-blocks
        }

        // Emit the internal event last to spend some gas after try / catch.
        emit Transfer(pool, from, address(0), amount);
    }

    function _transfer(address pool, address from, address to, uint256 amount) internal {
        if (from == address(0)) {
            revert ERC20InvalidSender(from);
        }

        if (to == address(0)) {
            revert ERC20InvalidReceiver(to);
        }

        uint256 fromBalance = _balances[pool][from];
        if (amount > fromBalance) {
            revert ERC20InsufficientBalance(from, fromBalance, amount);
        }

        unchecked {
            _balances[pool][from] = fromBalance - amount;
            // Overflow is not possible. The sum of all balances is capped by totalSupply, and that sum is preserved by
            // decrementing then incrementing.
            _balances[pool][to] += amount;
        }

        emit Transfer(pool, from, to, amount);

        // We also emit the "transfer" event on the pool token to ensure full compliance with the ERC20 standard.
        BalancerPoolToken(pool).emitTransfer(from, to, amount);
    }

    function _approve(address pool, address owner, address spender, uint256 amount) internal {
        if (owner == address(0)) {
            revert ERC20InvalidApprover(owner);
        }

        if (spender == address(0)) {
            revert ERC20InvalidSpender(spender);
        }

        _allowances[pool][owner][spender] = amount;

        // We also emit the "approve" event on the pool token to ensure full compliance with the ERC20 standard.
        // If this function fails we keep going, as this is used in recovery mode.
        // Well-behaved pools will just emit an event here, so they should never fail.
        try BalancerPoolToken(pool).emitApproval(owner, spender, amount) {} catch {
            // solhint-disable-previous-line no-empty-blocks
        }

        // Emit the internal event last to spend some gas after try / catch.
        emit Approval(pool, owner, spender, amount);
    }

    function _spendAllowance(address pool, address owner, address spender, uint256 amount) internal {
        uint256 currentAllowance = _allowance(pool, owner, spender);
        if (currentAllowance != type(uint256).max) {
            if (amount > currentAllowance) {
                revert ERC20InsufficientAllowance(spender, currentAllowance, amount);
            }

            unchecked {
                _approve(pool, owner, spender, currentAllowance - amount);
            }
        }
    }
}


// File: contracts/Vault.sol

// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.24;

import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { Proxy } from "@openzeppelin/contracts/proxy/Proxy.sol";

import { IProtocolFeeController } from "@balancer-labs/v3-interfaces/contracts/vault/IProtocolFeeController.sol";
import { IVaultExtension } from "@balancer-labs/v3-interfaces/contracts/vault/IVaultExtension.sol";
import { IPoolLiquidity } from "@balancer-labs/v3-interfaces/contracts/vault/IPoolLiquidity.sol";
import { IAuthorizer } from "@balancer-labs/v3-interfaces/contracts/vault/IAuthorizer.sol";
import { IVaultAdmin } from "@balancer-labs/v3-interfaces/contracts/vault/IVaultAdmin.sol";
import { IVaultMain } from "@balancer-labs/v3-interfaces/contracts/vault/IVaultMain.sol";
import { IBasePool } from "@balancer-labs/v3-interfaces/contracts/vault/IBasePool.sol";
import { IHooks } from "@balancer-labs/v3-interfaces/contracts/vault/IHooks.sol";
import "@balancer-labs/v3-interfaces/contracts/vault/VaultTypes.sol";

import { StorageSlotExtension } from "@balancer-labs/v3-solidity-utils/contracts/openzeppelin/StorageSlotExtension.sol";
import { PackedTokenBalance } from "@balancer-labs/v3-solidity-utils/contracts/helpers/PackedTokenBalance.sol";
import { ScalingHelpers } from "@balancer-labs/v3-solidity-utils/contracts/helpers/ScalingHelpers.sol";
import { CastingHelpers } from "@balancer-labs/v3-solidity-utils/contracts/helpers/CastingHelpers.sol";
import { BufferHelpers } from "@balancer-labs/v3-solidity-utils/contracts/helpers/BufferHelpers.sol";
import { InputHelpers } from "@balancer-labs/v3-solidity-utils/contracts/helpers/InputHelpers.sol";
import { FixedPoint } from "@balancer-labs/v3-solidity-utils/contracts/math/FixedPoint.sol";
import {
    TransientStorageHelpers
} from "@balancer-labs/v3-solidity-utils/contracts/helpers/TransientStorageHelpers.sol";

import { VaultStateLib, VaultStateBits } from "./lib/VaultStateLib.sol";
import { HooksConfigLib } from "./lib/HooksConfigLib.sol";
import { PoolConfigLib } from "./lib/PoolConfigLib.sol";
import { PoolDataLib } from "./lib/PoolDataLib.sol";
import { BasePoolMath } from "./BasePoolMath.sol";
import { VaultCommon } from "./VaultCommon.sol";

contract Vault is IVaultMain, VaultCommon, Proxy {
    using PackedTokenBalance for bytes32;
    using BufferHelpers for bytes32;
    using InputHelpers for uint256;
    using FixedPoint for *;
    using Address for *;
    using CastingHelpers for uint256[];
    using SafeCast for *;
    using SafeERC20 for IERC20;
    using PoolConfigLib for PoolConfigBits;
    using HooksConfigLib for PoolConfigBits;
    using VaultStateLib for VaultStateBits;
    using ScalingHelpers for *;
    using TransientStorageHelpers for *;
    using StorageSlotExtension for *;
    using PoolDataLib for PoolData;

    // Local reference to the Proxy pattern Vault extension contract.
    IVaultExtension private immutable _vaultExtension;

    constructor(IVaultExtension vaultExtension, IAuthorizer authorizer, IProtocolFeeController protocolFeeController) {
        if (address(vaultExtension.vault()) != address(this)) {
            revert WrongVaultExtensionDeployment();
        }

        if (address(protocolFeeController.vault()) != address(this)) {
            revert WrongProtocolFeeControllerDeployment();
        }

        _vaultExtension = vaultExtension;
        _protocolFeeController = protocolFeeController;

        _vaultPauseWindowEndTime = IVaultAdmin(address(vaultExtension)).getPauseWindowEndTime();
        _vaultBufferPeriodDuration = IVaultAdmin(address(vaultExtension)).getBufferPeriodDuration();
        _vaultBufferPeriodEndTime = IVaultAdmin(address(vaultExtension)).getBufferPeriodEndTime();

        _MINIMUM_TRADE_AMOUNT = IVaultAdmin(address(vaultExtension)).getMinimumTradeAmount();
        _MINIMUM_WRAP_AMOUNT = IVaultAdmin(address(vaultExtension)).getMinimumWrapAmount();

        _authorizer = authorizer;
    }

    /*******************************************************************************
                              Transient Accounting
    *******************************************************************************/

    /**
     * @dev This modifier is used for functions that temporarily modify the token deltas
     * of the Vault, but expect to revert or settle balances by the end of their execution.
     * It works by ensuring that the balances are properly settled by the time the last
     * operation is executed.
     *
     * This is useful for functions like `unlock`, which perform arbitrary external calls:
     * we can keep track of temporary deltas changes, and make sure they are settled by the
     * time the external call is complete.
     */
    modifier transient() {
        bool isUnlockedBefore = _isUnlocked().tload();

        if (isUnlockedBefore == false) {
            _isUnlocked().tstore(true);
        }

        // The caller does everything here and has to settle all outstanding balances.
        _;

        if (isUnlockedBefore == false) {
            if (_nonZeroDeltaCount().tload() != 0) {
                revert BalanceNotSettled();
            }

            _isUnlocked().tstore(false);

            // If a user adds liquidity to a pool, then does a proportional withdrawal from that pool during the same
            // interaction, the system charges a "round-trip" fee on the withdrawal. This fee makes it harder for an
            // user to add liquidity to a pool using a virtually infinite flash loan, swapping in the same pool in a way
            // that benefits him and removes liquidity in the same transaction, which is not a valid use case.
            //
            // Here we introduce the "session" concept, to prevent this fee from being charged accidentally. For
            // example, if an aggregator or account abstraction contract bundled several unrelated operations in the
            // same transaction that involved the same pool with different senders, the guardrail could be triggered
            // for a user doing a simple withdrawal. If proper limits were set, the whole transaction would revert,
            // and if they were not, the user would be unfairly "taxed."
            //
            // Defining an "interaction" this way - as a single `unlock` call vs. an entire transaction - prevents the
            // guardrail from being triggered in the cases described above.

            // Increase session counter after locking the Vault.
            _sessionIdSlot().tIncrement();
        }
    }

    /// @inheritdoc IVaultMain
    function unlock(bytes calldata data) external transient returns (bytes memory result) {
        return (msg.sender).functionCall(data);
    }

    /// @inheritdoc IVaultMain
    function settle(IERC20 token, uint256 amountHint) external nonReentrant onlyWhenUnlocked returns (uint256 credit) {
        uint256 reservesBefore = _reservesOf[token];
        uint256 currentReserves = token.balanceOf(address(this));
        _reservesOf[token] = currentReserves;
        credit = currentReserves - reservesBefore;

        // If the given hint is equal or greater to the reserve difference, we just take the actual reserve difference
        // as the paid amount; the actual balance of the tokens in the Vault is what matters here.
        if (credit > amountHint) {
            // If the difference in reserves is higher than the amount claimed to be paid by the caller, there was some
            // leftover that had been sent to the Vault beforehand, which was not incorporated into the reserves.
            // In that case, we simply discard the leftover by considering the given hint as the amount paid.
            // In turn, this gives the caller credit for the given amount hint, which is what the caller is expecting.
            credit = amountHint;
        }

        _supplyCredit(token, credit);
    }

    /// @inheritdoc IVaultMain
    function sendTo(IERC20 token, address to, uint256 amount) external nonReentrant onlyWhenUnlocked {
        _takeDebt(token, amount);
        _reservesOf[token] -= amount;

        token.safeTransfer(to, amount);
    }

    /*******************************************************************************
                                    Pool Operations
    *******************************************************************************/

    // The Vault performs all upscaling and downscaling (due to token decimals, rates, etc.), so that the pools
    // don't have to. However, scaling inevitably leads to rounding errors, so we take great care to ensure that
    // any rounding errors favor the Vault. An important invariant of the system is that there is no repeatable
    // path where tokensOut > tokensIn.
    //
    // In general, this means rounding up any values entering the Vault, and rounding down any values leaving
    // the Vault, so that external users either pay a little extra or receive a little less in the case of a
    // rounding error.
    //
    // However, it's not always straightforward to determine the correct rounding direction, given the presence
    // and complexity of intermediate steps. An "amountIn" sounds like it should be rounded up: but only if that
    // is the amount actually being transferred. If instead it is an amount sent to the pool math, where rounding
    // up would result in a *higher* calculated amount out, that would favor the user instead of the Vault. So in
    // that case, amountIn should be rounded down.
    //
    // See comments justifying the rounding direction in each case.
    //
    // This reasoning applies to Weighted Pool math, and is likely to apply to others as well, but of course
    // it's possible a new pool type might not conform. Duplicate the tests for new pool types (e.g., Stable Math).
    // Also, the final code should ensure that we are not relying entirely on the rounding directions here,
    // but have enough additional layers (e.g., minimum amounts, buffer wei on all transfers) to guarantee safety,
    // even if it turns out these directions are incorrect for a new pool type.

    /*******************************************************************************
                                          Swaps
    *******************************************************************************/

    /// @inheritdoc IVaultMain
    function swap(
        VaultSwapParams memory vaultSwapParams
    )
        external
        onlyWhenUnlocked
        withInitializedPool(vaultSwapParams.pool)
        returns (uint256 amountCalculated, uint256 amountIn, uint256 amountOut)
    {
        _ensureUnpaused(vaultSwapParams.pool);

        if (vaultSwapParams.amountGivenRaw == 0) {
            revert AmountGivenZero();
        }

        if (vaultSwapParams.tokenIn == vaultSwapParams.tokenOut) {
            revert CannotSwapSameToken();
        }

        // `_loadPoolDataUpdatingBalancesAndYieldFees` is non-reentrant, as it updates storage as well
        // as filling in poolData in memory. Since the swap hooks are reentrant and could do anything, including
        // change these balances, we cannot defer settlement until `_swap`.
        //
        // Sets all fields in `poolData`. Side effects: updates `_poolTokenBalances`, `_aggregateFeeAmounts`
        // in storage.
        PoolData memory poolData = _loadPoolDataUpdatingBalancesAndYieldFees(vaultSwapParams.pool, Rounding.ROUND_DOWN);
        SwapState memory swapState = _loadSwapState(vaultSwapParams, poolData);
        PoolSwapParams memory poolSwapParams = _buildPoolSwapParams(vaultSwapParams, swapState, poolData);

        if (poolData.poolConfigBits.shouldCallBeforeSwap()) {
            HooksConfigLib.callBeforeSwapHook(
                poolSwapParams,
                vaultSwapParams.pool,
                _hooksContracts[vaultSwapParams.pool]
            );

            // The call to `onBeforeSwap` could potentially update token rates and balances.
            // We update `poolData.tokenRates`, `poolData.rawBalances` and `poolData.balancesLiveScaled18`
            // to ensure the `onSwap` and `onComputeDynamicSwapFeePercentage` are called with the current values.
            poolData.reloadBalancesAndRates(_poolTokenBalances[vaultSwapParams.pool], Rounding.ROUND_DOWN);

            // Also update amountGivenScaled18, as it will now be used in the swap, and the rates might have changed.
            swapState.amountGivenScaled18 = _computeAmountGivenScaled18(vaultSwapParams, poolData, swapState);

            poolSwapParams = _buildPoolSwapParams(vaultSwapParams, swapState, poolData);
        }

        // Note that this must be called *after* the before hook, to guarantee that the swap params are the same
        // as those passed to the main operation.
        //
        // At this point, the static swap fee percentage is loaded in the `swapState` as the default, to be used
        // unless the pool has a dynamic swap fee. It is also passed into the hook, to support common cases
        // where the dynamic fee computation logic uses it.
        if (poolData.poolConfigBits.shouldCallComputeDynamicSwapFee()) {
            swapState.swapFeePercentage = HooksConfigLib.callComputeDynamicSwapFeeHook(
                poolSwapParams,
                vaultSwapParams.pool,
                swapState.swapFeePercentage,
                _hooksContracts[vaultSwapParams.pool]
            );
        }

        // Non-reentrant call that updates accounting.
        // The following side-effects are important to note:
        // PoolData balancesRaw and balancesLiveScaled18 are adjusted for swap amounts and fees inside of _swap.
        uint256 amountCalculatedScaled18;
        (amountCalculated, amountCalculatedScaled18, amountIn, amountOut) = _swap(
            vaultSwapParams,
            swapState,
            poolData,
            poolSwapParams
        );

        // The new amount calculated is 'amountCalculated + delta'. If the underlying hook fails, or limits are
        // violated, `onAfterSwap` will revert. Uses msg.sender as the Router (the contract that called the Vault).
        if (poolData.poolConfigBits.shouldCallAfterSwap()) {
            // `hooksContract` needed to fix stack too deep.
            IHooks hooksContract = _hooksContracts[vaultSwapParams.pool];

            amountCalculated = poolData.poolConfigBits.callAfterSwapHook(
                amountCalculatedScaled18,
                amountCalculated,
                msg.sender,
                vaultSwapParams,
                swapState,
                poolData,
                hooksContract
            );
        }

        if (vaultSwapParams.kind == SwapKind.EXACT_IN) {
            amountOut = amountCalculated;
        } else {
            amountIn = amountCalculated;
        }
    }

    function _loadSwapState(
        VaultSwapParams memory vaultSwapParams,
        PoolData memory poolData
    ) private pure returns (SwapState memory swapState) {
        swapState.indexIn = _findTokenIndex(poolData.tokens, vaultSwapParams.tokenIn);
        swapState.indexOut = _findTokenIndex(poolData.tokens, vaultSwapParams.tokenOut);

        swapState.amountGivenScaled18 = _computeAmountGivenScaled18(vaultSwapParams, poolData, swapState);
        swapState.swapFeePercentage = poolData.poolConfigBits.getStaticSwapFeePercentage();
    }

    function _buildPoolSwapParams(
        VaultSwapParams memory vaultSwapParams,
        SwapState memory swapState,
        PoolData memory poolData
    ) internal view returns (PoolSwapParams memory) {
        // Uses msg.sender as the Router (the contract that called the Vault).
        return
            PoolSwapParams({
                kind: vaultSwapParams.kind,
                amountGivenScaled18: swapState.amountGivenScaled18,
                balancesScaled18: poolData.balancesLiveScaled18,
                indexIn: swapState.indexIn,
                indexOut: swapState.indexOut,
                router: msg.sender,
                userData: vaultSwapParams.userData
            });
    }

    /**
     * @dev Preconditions: decimalScalingFactors and tokenRates in `poolData` must be current.
     * Uses amountGivenRaw and kind from `vaultSwapParams`.
     */
    function _computeAmountGivenScaled18(
        VaultSwapParams memory vaultSwapParams,
        PoolData memory poolData,
        SwapState memory swapState
    ) private pure returns (uint256) {
        // If the amountGiven is entering the pool math (ExactIn), round down, since a lower apparent amountIn leads
        // to a lower calculated amountOut, favoring the pool.
        return
            vaultSwapParams.kind == SwapKind.EXACT_IN
                ? vaultSwapParams.amountGivenRaw.toScaled18ApplyRateRoundDown(
                    poolData.decimalScalingFactors[swapState.indexIn],
                    poolData.tokenRates[swapState.indexIn]
                )
                : vaultSwapParams.amountGivenRaw.toScaled18ApplyRateRoundUp(
                    poolData.decimalScalingFactors[swapState.indexOut],
                    // If the swap is ExactOut, the amountGiven is the amount of tokenOut. So, we want to use the rate
                    // rounded up to calculate the amountGivenScaled18, because if this value is bigger, the
                    // amountCalculatedRaw will be bigger, implying that the user will pay for any rounding
                    // inconsistency, and not the Vault.
                    poolData.tokenRates[swapState.indexOut].computeRateRoundUp()
                );
    }

    /**
     * @dev Auxiliary struct to prevent stack-too-deep issues inside `_swap` function.
     * Total swap fees include LP (pool) fees and aggregate (protocol + pool creator) fees.
     */
    struct SwapInternalLocals {
        uint256 totalSwapFeeAmountScaled18;
        uint256 totalSwapFeeAmountRaw;
        uint256 aggregateFeeAmountRaw;
    }

    /**
     * @dev Main non-reentrant portion of the swap, which calls the pool hook and updates accounting. `vaultSwapParams`
     * are passed to the pool's `onSwap` hook.
     *
     * Preconditions: complete `SwapParams`, `SwapState`, and `PoolData`.
     * Side effects: mutates balancesRaw and balancesLiveScaled18 in `poolData`.
     * Updates `_aggregateFeeAmounts`, and `_poolTokenBalances` in storage.
     * Emits Swap event.
     */
    function _swap(
        VaultSwapParams memory vaultSwapParams,
        SwapState memory swapState,
        PoolData memory poolData,
        PoolSwapParams memory poolSwapParams
    )
        internal
        nonReentrant
        returns (
            uint256 amountCalculatedRaw,
            uint256 amountCalculatedScaled18,
            uint256 amountInRaw,
            uint256 amountOutRaw
        )
    {
        SwapInternalLocals memory locals;

        if (vaultSwapParams.kind == SwapKind.EXACT_IN) {
            // Round up to avoid losses during precision loss.
            locals.totalSwapFeeAmountScaled18 = poolSwapParams.amountGivenScaled18.mulUp(swapState.swapFeePercentage);
            poolSwapParams.amountGivenScaled18 -= locals.totalSwapFeeAmountScaled18;
        }

        _ensureValidSwapAmount(poolSwapParams.amountGivenScaled18);

        // Perform the swap request hook and compute the new balances for 'token in' and 'token out' after the swap.
        amountCalculatedScaled18 = IBasePool(vaultSwapParams.pool).onSwap(poolSwapParams);

        _ensureValidSwapAmount(amountCalculatedScaled18);

        // Note that balances are kept in memory, and are not fully computed until the `setPoolBalances` below.
        // Intervening code cannot read balances from storage, as they are temporarily out-of-sync here. This function
        // is nonReentrant, to guard against read-only reentrancy issues.

        // (1) and (2): get raw amounts and check limits.
        if (vaultSwapParams.kind == SwapKind.EXACT_IN) {
            // Restore the original input value; this function should not mutate memory inputs.
            // At this point swap fee amounts have already been computed for EXACT_IN.
            poolSwapParams.amountGivenScaled18 = swapState.amountGivenScaled18;

            // For `ExactIn` the amount calculated is leaving the Vault, so we round down.
            amountCalculatedRaw = amountCalculatedScaled18.toRawUndoRateRoundDown(
                poolData.decimalScalingFactors[swapState.indexOut],
                // If the swap is ExactIn, the amountCalculated is the amount of tokenOut. So, we want to use the rate
                // rounded up to calculate the amountCalculatedRaw, because scale down (undo rate) is a division, the
                // larger the rate, the smaller the amountCalculatedRaw. So, any rounding imprecision will stay in the
                // Vault and not be drained by the user.
                poolData.tokenRates[swapState.indexOut].computeRateRoundUp()
            );

            (amountInRaw, amountOutRaw) = (vaultSwapParams.amountGivenRaw, amountCalculatedRaw);

            if (amountOutRaw < vaultSwapParams.limitRaw) {
                revert SwapLimit(amountOutRaw, vaultSwapParams.limitRaw);
            }
        } else {
            // To ensure symmetry with EXACT_IN, the swap fee used by ExactOut is
            // `amountCalculated * fee% / (100% - fee%)`. Add it to the calculated amountIn. Round up to avoid losing
            // value due to precision loss. Note that if the `swapFeePercentage` were 100% here, this would revert with
            // division by zero. We protect against this by ensuring in PoolConfigLib and HooksConfigLib that all swap
            // fees (static, dynamic, pool creator, and aggregate) are less than 100%.
            locals.totalSwapFeeAmountScaled18 = amountCalculatedScaled18.mulDivUp(
                swapState.swapFeePercentage,
                swapState.swapFeePercentage.complement()
            );

            amountCalculatedScaled18 += locals.totalSwapFeeAmountScaled18;

            // For `ExactOut` the amount calculated is entering the Vault, so we round up.
            amountCalculatedRaw = amountCalculatedScaled18.toRawUndoRateRoundUp(
                poolData.decimalScalingFactors[swapState.indexIn],
                poolData.tokenRates[swapState.indexIn]
            );

            (amountInRaw, amountOutRaw) = (amountCalculatedRaw, vaultSwapParams.amountGivenRaw);

            if (amountInRaw > vaultSwapParams.limitRaw) {
                revert SwapLimit(amountInRaw, vaultSwapParams.limitRaw);
            }
        }

        // 3) Deltas: debit for token in, credit for token out.
        _takeDebt(vaultSwapParams.tokenIn, amountInRaw);
        _supplyCredit(vaultSwapParams.tokenOut, amountOutRaw);

        // 4) Compute and charge protocol and creator fees.
        // Note that protocol fee storage is updated before balance storage, as the final raw balances need to take
        // the fees into account.
        (locals.totalSwapFeeAmountRaw, locals.aggregateFeeAmountRaw) = _computeAndChargeAggregateSwapFees(
            poolData,
            locals.totalSwapFeeAmountScaled18,
            vaultSwapParams.pool,
            vaultSwapParams.tokenIn,
            swapState.indexIn
        );

        // 5) Pool balances: raw and live.

        poolData.updateRawAndLiveBalance(
            swapState.indexIn,
            poolData.balancesRaw[swapState.indexIn] + amountInRaw - locals.aggregateFeeAmountRaw,
            Rounding.ROUND_DOWN
        );
        poolData.updateRawAndLiveBalance(
            swapState.indexOut,
            poolData.balancesRaw[swapState.indexOut] - amountOutRaw,
            Rounding.ROUND_DOWN
        );

        // 6) Store pool balances, raw and live (only index in and out).
        mapping(uint256 tokenIndex => bytes32 packedTokenBalance) storage poolBalances = _poolTokenBalances[
            vaultSwapParams.pool
        ];
        poolBalances[swapState.indexIn] = PackedTokenBalance.toPackedBalance(
            poolData.balancesRaw[swapState.indexIn],
            poolData.balancesLiveScaled18[swapState.indexIn]
        );
        poolBalances[swapState.indexOut] = PackedTokenBalance.toPackedBalance(
            poolData.balancesRaw[swapState.indexOut],
            poolData.balancesLiveScaled18[swapState.indexOut]
        );

        // 7) Off-chain events.
        emit Swap(
            vaultSwapParams.pool,
            vaultSwapParams.tokenIn,
            vaultSwapParams.tokenOut,
            amountInRaw,
            amountOutRaw,
            swapState.swapFeePercentage,
            locals.totalSwapFeeAmountRaw
        );
    }

    /***************************************************************************
                                   Add Liquidity
    ***************************************************************************/

    /// @inheritdoc IVaultMain
    function addLiquidity(
        AddLiquidityParams memory params
    )
        external
        onlyWhenUnlocked
        withInitializedPool(params.pool)
        returns (uint256[] memory amountsIn, uint256 bptAmountOut, bytes memory returnData)
    {
        // Round balances up when adding liquidity:
        // If proportional, higher balances = higher proportional amountsIn, favoring the pool.
        // If unbalanced, higher balances = lower invariant ratio with fees.
        // bptOut = supply * (ratio - 1), so lower ratio = less bptOut, favoring the pool.

        _ensureUnpaused(params.pool);
        _addLiquidityCalled().tSet(_sessionIdSlot().tload(), params.pool, true);

        // `_loadPoolDataUpdatingBalancesAndYieldFees` is non-reentrant, as it updates storage as well
        // as filling in poolData in memory. Since the add liquidity hooks are reentrant and could do anything,
        // including change these balances, we cannot defer settlement until `_addLiquidity`.
        //
        // Sets all fields in `poolData`. Side effects: updates `_poolTokenBalances`, and
        // `_aggregateFeeAmounts` in storage.
        PoolData memory poolData = _loadPoolDataUpdatingBalancesAndYieldFees(params.pool, Rounding.ROUND_UP);
        InputHelpers.ensureInputLengthMatch(poolData.tokens.length, params.maxAmountsIn.length);

        // Amounts are entering pool math, so round down.
        // Introducing `maxAmountsInScaled18` here and passing it through to _addLiquidity is not ideal,
        // but it avoids the even worse options of mutating amountsIn inside AddLiquidityParams,
        // or cluttering the AddLiquidityParams interface by adding amountsInScaled18.
        uint256[] memory maxAmountsInScaled18 = params.maxAmountsIn.copyToScaled18ApplyRateRoundDownArray(
            poolData.decimalScalingFactors,
            poolData.tokenRates
        );

        if (poolData.poolConfigBits.shouldCallBeforeAddLiquidity()) {
            HooksConfigLib.callBeforeAddLiquidityHook(
                msg.sender,
                maxAmountsInScaled18,
                params,
                poolData,
                _hooksContracts[params.pool]
            );
            // The hook might have altered the balances, so we need to read them again to ensure that the data
            // are fresh moving forward. We also need to upscale (adding liquidity, so round up) again.
            poolData.reloadBalancesAndRates(_poolTokenBalances[params.pool], Rounding.ROUND_UP);

            // Also update maxAmountsInScaled18, as the rates might have changed.
            maxAmountsInScaled18 = params.maxAmountsIn.copyToScaled18ApplyRateRoundDownArray(
                poolData.decimalScalingFactors,
                poolData.tokenRates
            );
        }

        // The bulk of the work is done here: the corresponding Pool hook is called, and the final balances
        // are computed. This function is non-reentrant, as it performs the accounting updates.
        //
        // Note that poolData is mutated to update the Raw and Live balances, so they are accurate when passed
        // into the AfterAddLiquidity hook.
        //
        // `amountsInScaled18` will be overwritten in the custom case, so we need to pass it back and forth to
        // encapsulate that logic in `_addLiquidity`.
        uint256[] memory amountsInScaled18;
        (amountsIn, amountsInScaled18, bptAmountOut, returnData) = _addLiquidity(
            poolData,
            params,
            maxAmountsInScaled18
        );

        // AmountsIn can be changed by onAfterAddLiquidity if the hook charges fees or gives discounts.
        // Uses msg.sender as the Router (the contract that called the Vault).
        if (poolData.poolConfigBits.shouldCallAfterAddLiquidity()) {
            // `hooksContract` needed to fix stack too deep.
            IHooks hooksContract = _hooksContracts[params.pool];

            amountsIn = poolData.poolConfigBits.callAfterAddLiquidityHook(
                msg.sender,
                amountsInScaled18,
                amountsIn,
                bptAmountOut,
                params,
                poolData,
                hooksContract
            );
        }
    }

    // Avoid "stack too deep" - without polluting the Add/RemoveLiquidity params interface.
    struct LiquidityLocals {
        uint256 numTokens;
        uint256 aggregateSwapFeeAmountRaw;
        uint256 tokenIndex;
    }

    /**
     * @dev Calls the appropriate pool hook and calculates the required inputs and outputs for the operation
     * considering the given kind, and updates the Vault's internal accounting. This includes:
     * - Setting pool balances
     * - Taking debt from the liquidity provider
     * - Minting pool tokens
     * - Emitting events
     *
     * It is non-reentrant, as it performs external calls and updates the Vault's state accordingly.
     */
    function _addLiquidity(
        PoolData memory poolData,
        AddLiquidityParams memory params,
        uint256[] memory maxAmountsInScaled18
    )
        internal
        nonReentrant
        returns (
            uint256[] memory amountsInRaw,
            uint256[] memory amountsInScaled18,
            uint256 bptAmountOut,
            bytes memory returnData
        )
    {
        LiquidityLocals memory locals;
        locals.numTokens = poolData.tokens.length;
        amountsInRaw = new uint256[](locals.numTokens);
        // `swapFeeAmounts` stores scaled18 amounts first, and is then reused to store raw amounts.
        uint256[] memory swapFeeAmounts;

        if (params.kind == AddLiquidityKind.PROPORTIONAL) {
            bptAmountOut = params.minBptAmountOut;
            // Initializes the swapFeeAmounts empty array (no swap fees on proportional add liquidity).
            swapFeeAmounts = new uint256[](locals.numTokens);

            amountsInScaled18 = BasePoolMath.computeProportionalAmountsIn(
                poolData.balancesLiveScaled18,
                _totalSupply(params.pool),
                bptAmountOut
            );
        } else if (params.kind == AddLiquidityKind.DONATION) {
            poolData.poolConfigBits.requireDonationEnabled();

            swapFeeAmounts = new uint256[](maxAmountsInScaled18.length);
            bptAmountOut = 0;
            amountsInScaled18 = maxAmountsInScaled18;
        } else if (params.kind == AddLiquidityKind.UNBALANCED) {
            poolData.poolConfigBits.requireUnbalancedLiquidityEnabled();

            amountsInScaled18 = maxAmountsInScaled18;
            // Deep copy given max amounts in raw to calculated amounts in raw to avoid scaling later, ensuring that
            // `maxAmountsIn` is preserved.
            ScalingHelpers.copyToArray(params.maxAmountsIn, amountsInRaw);

            (bptAmountOut, swapFeeAmounts) = BasePoolMath.computeAddLiquidityUnbalanced(
                poolData.balancesLiveScaled18,
                maxAmountsInScaled18,
                _totalSupply(params.pool),
                poolData.poolConfigBits.getStaticSwapFeePercentage(),
                IBasePool(params.pool)
            );
        } else if (params.kind == AddLiquidityKind.SINGLE_TOKEN_EXACT_OUT) {
            poolData.poolConfigBits.requireUnbalancedLiquidityEnabled();

            bptAmountOut = params.minBptAmountOut;
            locals.tokenIndex = InputHelpers.getSingleInputIndex(maxAmountsInScaled18);

            amountsInScaled18 = maxAmountsInScaled18;
            (amountsInScaled18[locals.tokenIndex], swapFeeAmounts) = BasePoolMath
                .computeAddLiquiditySingleTokenExactOut(
                    poolData.balancesLiveScaled18,
                    locals.tokenIndex,
                    bptAmountOut,
                    _totalSupply(params.pool),
                    poolData.poolConfigBits.getStaticSwapFeePercentage(),
                    IBasePool(params.pool)
                );
        } else if (params.kind == AddLiquidityKind.CUSTOM) {
            poolData.poolConfigBits.requireAddLiquidityCustomEnabled();

            // Uses msg.sender as the Router (the contract that called the Vault).
            (amountsInScaled18, bptAmountOut, swapFeeAmounts, returnData) = IPoolLiquidity(params.pool)
                .onAddLiquidityCustom(
                    msg.sender,
                    maxAmountsInScaled18,
                    params.minBptAmountOut,
                    poolData.balancesLiveScaled18,
                    params.userData
                );
        } else {
            revert InvalidAddLiquidityKind();
        }

        // At this point we have the calculated BPT amount.
        if (bptAmountOut < params.minBptAmountOut) {
            revert BptAmountOutBelowMin(bptAmountOut, params.minBptAmountOut);
        }

        _ensureValidTradeAmount(bptAmountOut);

        for (uint256 i = 0; i < locals.numTokens; ++i) {
            uint256 amountInRaw;

            // 1) Calculate raw amount in.
            {
                uint256 amountInScaled18 = amountsInScaled18[i];
                _ensureValidTradeAmount(amountInScaled18);

                // If the value in memory is not set, convert scaled amount to raw.
                if (amountsInRaw[i] == 0) {
                    // amountsInRaw are amounts actually entering the Pool, so we round up.
                    // Do not mutate in place yet, as we need them scaled for the `onAfterAddLiquidity` hook.
                    amountInRaw = amountInScaled18.toRawUndoRateRoundUp(
                        poolData.decimalScalingFactors[i],
                        poolData.tokenRates[i]
                    );

                    amountsInRaw[i] = amountInRaw;
                } else {
                    // Exact in requests will have the raw amount in memory already, so we use it moving forward and
                    // skip downscaling.
                    amountInRaw = amountsInRaw[i];
                }
            }

            IERC20 token = poolData.tokens[i];

            // 2) Check limits for raw amounts.
            if (amountInRaw > params.maxAmountsIn[i]) {
                revert AmountInAboveMax(token, amountInRaw, params.maxAmountsIn[i]);
            }

            // 3) Deltas: Debit of token[i] for amountInRaw.
            _takeDebt(token, amountInRaw);

            // 4) Compute and charge protocol and creator fees.
            // swapFeeAmounts[i] is now raw instead of scaled.
            (swapFeeAmounts[i], locals.aggregateSwapFeeAmountRaw) = _computeAndChargeAggregateSwapFees(
                poolData,
                swapFeeAmounts[i],
                params.pool,
                token,
                i
            );

            // 5) Pool balances: raw and live.
            // We need regular balances to complete the accounting, and the upscaled balances
            // to use in the `after` hook later on.

            // A pool's token balance increases by amounts in after adding liquidity, minus fees.
            poolData.updateRawAndLiveBalance(
                i,
                poolData.balancesRaw[i] + amountInRaw - locals.aggregateSwapFeeAmountRaw,
                Rounding.ROUND_DOWN
            );
        }

        // 6) Store pool balances, raw and live.
        _writePoolBalancesToStorage(params.pool, poolData);

        // 7) BPT supply adjustment.
        // When adding liquidity, we must mint tokens concurrently with updating pool balances,
        // as the pool's math relies on totalSupply.
        _mint(address(params.pool), params.to, bptAmountOut);

        // 8) Off-chain events.
        emit LiquidityAdded(
            params.pool,
            params.to,
            params.kind,
            _totalSupply(params.pool),
            amountsInRaw,
            swapFeeAmounts
        );
    }

    /***************************************************************************
                                 Remove Liquidity
    ***************************************************************************/

    /// @inheritdoc IVaultMain
    function removeLiquidity(
        RemoveLiquidityParams memory params
    )
        external
        onlyWhenUnlocked
        withInitializedPool(params.pool)
        returns (uint256 bptAmountIn, uint256[] memory amountsOut, bytes memory returnData)
    {
        // Round down when removing liquidity:
        // If proportional, lower balances = lower proportional amountsOut, favoring the pool.
        // If unbalanced, lower balances = lower invariant ratio without fees.
        // bptIn = supply * (1 - ratio), so lower ratio = more bptIn, favoring the pool.
        _ensureUnpaused(params.pool);

        // `_loadPoolDataUpdatingBalancesAndYieldFees` is non-reentrant, as it updates storage as well
        // as filling in poolData in memory. Since the swap hooks are reentrant and could do anything, including
        // change these balances, we cannot defer settlement until `_removeLiquidity`.
        //
        // Sets all fields in `poolData`. Side effects: updates `_poolTokenBalances` and
        // `_aggregateFeeAmounts in storage.
        PoolData memory poolData = _loadPoolDataUpdatingBalancesAndYieldFees(params.pool, Rounding.ROUND_DOWN);
        InputHelpers.ensureInputLengthMatch(poolData.tokens.length, params.minAmountsOut.length);

        // Amounts are entering pool math; higher amounts would burn more BPT, so round up to favor the pool.
        // Do not mutate minAmountsOut, so that we can directly compare the raw limits later, without potentially
        // losing precision by scaling up and then down.
        uint256[] memory minAmountsOutScaled18 = params.minAmountsOut.copyToScaled18ApplyRateRoundUpArray(
            poolData.decimalScalingFactors,
            poolData.tokenRates
        );

        // Uses msg.sender as the Router (the contract that called the Vault).
        if (poolData.poolConfigBits.shouldCallBeforeRemoveLiquidity()) {
            HooksConfigLib.callBeforeRemoveLiquidityHook(
                minAmountsOutScaled18,
                msg.sender,
                params,
                poolData,
                _hooksContracts[params.pool]
            );

            // The hook might alter the balances, so we need to read them again to ensure that the data is
            // fresh moving forward. We also need to upscale (removing liquidity, so round down) again.
            poolData.reloadBalancesAndRates(_poolTokenBalances[params.pool], Rounding.ROUND_DOWN);

            // Also update minAmountsOutScaled18, as the rates might have changed.
            minAmountsOutScaled18 = params.minAmountsOut.copyToScaled18ApplyRateRoundUpArray(
                poolData.decimalScalingFactors,
                poolData.tokenRates
            );
        }

        // The bulk of the work is done here: the corresponding Pool hook is called, and the final balances
        // are computed. This function is non-reentrant, as it performs the accounting updates.
        //
        // Note that poolData is mutated to update the Raw and Live balances, so they are accurate when passed
        // into the AfterRemoveLiquidity hook.
        uint256[] memory amountsOutScaled18;
        (bptAmountIn, amountsOut, amountsOutScaled18, returnData) = _removeLiquidity(
            poolData,
            params,
            minAmountsOutScaled18
        );

        // AmountsOut can be changed by onAfterRemoveLiquidity if the hook charges fees or gives discounts.
        // Uses msg.sender as the Router (the contract that called the Vault).
        if (poolData.poolConfigBits.shouldCallAfterRemoveLiquidity()) {
            // `hooksContract` needed to fix stack too deep.
            IHooks hooksContract = _hooksContracts[params.pool];

            amountsOut = poolData.poolConfigBits.callAfterRemoveLiquidityHook(
                msg.sender,
                amountsOutScaled18,
                amountsOut,
                bptAmountIn,
                params,
                poolData,
                hooksContract
            );
        }
    }

    /**
     * @dev Calls the appropriate pool hook and calculates the required inputs and outputs for the operation
     * considering the given kind, and updates the Vault's internal accounting. This includes:
     * - Setting pool balances
     * - Supplying credit to the liquidity provider
     * - Burning pool tokens
     * - Emitting events
     *
     * It is non-reentrant, as it performs external calls and updates the Vault's state accordingly.
     */
    function _removeLiquidity(
        PoolData memory poolData,
        RemoveLiquidityParams memory params,
        uint256[] memory minAmountsOutScaled18
    )
        internal
        nonReentrant
        returns (
            uint256 bptAmountIn,
            uint256[] memory amountsOutRaw,
            uint256[] memory amountsOutScaled18,
            bytes memory returnData
        )
    {
        LiquidityLocals memory locals;
        locals.numTokens = poolData.tokens.length;
        amountsOutRaw = new uint256[](locals.numTokens);
        // `swapFeeAmounts` stores scaled18 amounts first, and is then reused to store raw amounts.
        uint256[] memory swapFeeAmounts;

        if (params.kind == RemoveLiquidityKind.PROPORTIONAL) {
            bptAmountIn = params.maxBptAmountIn;
            swapFeeAmounts = new uint256[](locals.numTokens);
            amountsOutScaled18 = BasePoolMath.computeProportionalAmountsOut(
                poolData.balancesLiveScaled18,
                _totalSupply(params.pool),
                bptAmountIn
            );

            // Charge round-trip fee if liquidity was added to this pool in the same unlock call; this is not really a
            // valid use case, and may be an attack. Use caution when removing liquidity through a Safe or other
            // multisig / non-EOA address. Use "sign and execute," ideally through a private node (or at least not
            // allowing public execution) to avoid front-running, and always set strict limits so that it will revert
            // if any unexpected fees are charged. (It is also possible to check whether the flag has been set before
            // withdrawing, by calling `getAddLiquidityCalledFlag`.)
            if (_addLiquidityCalled().tGet(_sessionIdSlot().tload(), params.pool)) {
                uint256 swapFeePercentage = poolData.poolConfigBits.getStaticSwapFeePercentage();
                for (uint256 i = 0; i < locals.numTokens; ++i) {
                    swapFeeAmounts[i] = amountsOutScaled18[i].mulUp(swapFeePercentage);
                    amountsOutScaled18[i] -= swapFeeAmounts[i];
                }
            }
        } else if (params.kind == RemoveLiquidityKind.SINGLE_TOKEN_EXACT_IN) {
            poolData.poolConfigBits.requireUnbalancedLiquidityEnabled();
            bptAmountIn = params.maxBptAmountIn;
            amountsOutScaled18 = minAmountsOutScaled18;
            locals.tokenIndex = InputHelpers.getSingleInputIndex(params.minAmountsOut);

            (amountsOutScaled18[locals.tokenIndex], swapFeeAmounts) = BasePoolMath
                .computeRemoveLiquiditySingleTokenExactIn(
                    poolData.balancesLiveScaled18,
                    locals.tokenIndex,
                    bptAmountIn,
                    _totalSupply(params.pool),
                    poolData.poolConfigBits.getStaticSwapFeePercentage(),
                    IBasePool(params.pool)
                );
        } else if (params.kind == RemoveLiquidityKind.SINGLE_TOKEN_EXACT_OUT) {
            poolData.poolConfigBits.requireUnbalancedLiquidityEnabled();
            amountsOutScaled18 = minAmountsOutScaled18;
            locals.tokenIndex = InputHelpers.getSingleInputIndex(params.minAmountsOut);
            amountsOutRaw[locals.tokenIndex] = params.minAmountsOut[locals.tokenIndex];

            (bptAmountIn, swapFeeAmounts) = BasePoolMath.computeRemoveLiquiditySingleTokenExactOut(
                poolData.balancesLiveScaled18,
                locals.tokenIndex,
                amountsOutScaled18[locals.tokenIndex],
                _totalSupply(params.pool),
                poolData.poolConfigBits.getStaticSwapFeePercentage(),
                IBasePool(params.pool)
            );
        } else if (params.kind == RemoveLiquidityKind.CUSTOM) {
            poolData.poolConfigBits.requireRemoveLiquidityCustomEnabled();
            // Uses msg.sender as the Router (the contract that called the Vault).
            (bptAmountIn, amountsOutScaled18, swapFeeAmounts, returnData) = IPoolLiquidity(params.pool)
                .onRemoveLiquidityCustom(
                    msg.sender,
                    params.maxBptAmountIn,
                    minAmountsOutScaled18,
                    poolData.balancesLiveScaled18,
                    params.userData
                );
        } else {
            revert InvalidRemoveLiquidityKind();
        }

        if (bptAmountIn > params.maxBptAmountIn) {
            revert BptAmountInAboveMax(bptAmountIn, params.maxBptAmountIn);
        }

        _ensureValidTradeAmount(bptAmountIn);

        for (uint256 i = 0; i < locals.numTokens; ++i) {
            uint256 amountOutRaw;

            // 1) Calculate raw amount out.
            {
                uint256 amountOutScaled18 = amountsOutScaled18[i];
                _ensureValidTradeAmount(amountOutScaled18);

                // If the value in memory is not set, convert scaled amount to raw.
                if (amountsOutRaw[i] == 0) {
                    // amountsOut are amounts exiting the Pool, so we round down.
                    // Do not mutate in place yet, as we need them scaled for the `onAfterRemoveLiquidity` hook.
                    amountOutRaw = amountOutScaled18.toRawUndoRateRoundDown(
                        poolData.decimalScalingFactors[i],
                        poolData.tokenRates[i]
                    );
                    amountsOutRaw[i] = amountOutRaw;
                } else {
                    // Exact out requests will have the raw amount in memory already, so we use it moving forward and
                    // skip downscaling.
                    amountOutRaw = amountsOutRaw[i];
                }
            }

            IERC20 token = poolData.tokens[i];
            // 2) Check limits for raw amounts.
            if (amountOutRaw < params.minAmountsOut[i]) {
                revert AmountOutBelowMin(token, amountOutRaw, params.minAmountsOut[i]);
            }

            // 3) Deltas: Credit token[i] for amountOutRaw.
            _supplyCredit(token, amountOutRaw);

            // 4) Compute and charge protocol and creator fees.
            // swapFeeAmounts[i] is now raw instead of scaled.
            (swapFeeAmounts[i], locals.aggregateSwapFeeAmountRaw) = _computeAndChargeAggregateSwapFees(
                poolData,
                swapFeeAmounts[i],
                params.pool,
                token,
                i
            );

            // 5) Pool balances: raw and live.
            // We need regular balances to complete the accounting, and the upscaled balances
            // to use in the `after` hook later on.

            // A Pool's token balance always decreases after an exit (potentially by 0).
            // Also adjust by protocol and pool creator fees.
            poolData.updateRawAndLiveBalance(
                i,
                poolData.balancesRaw[i] - (amountOutRaw + locals.aggregateSwapFeeAmountRaw),
                Rounding.ROUND_DOWN
            );
        }

        // 6) Store pool balances, raw and live.
        _writePoolBalancesToStorage(params.pool, poolData);

        // 7) BPT supply adjustment.
        // Uses msg.sender as the Router (the contract that called the Vault).
        _spendAllowance(address(params.pool), params.from, msg.sender, bptAmountIn);

        if (_isQueryContext()) {
            // Increase `from` balance to ensure the burn function succeeds.
            _queryModeBalanceIncrease(params.pool, params.from, bptAmountIn);
        }
        // When removing liquidity, we must burn tokens concurrently with updating pool balances,
        // as the pool's math relies on totalSupply.
        // Burning will be reverted if it results in a total supply less than the _POOL_MINIMUM_TOTAL_SUPPLY.
        _burn(address(params.pool), params.from, bptAmountIn);

        // 8) Off-chain events.
        emit LiquidityRemoved(
            params.pool,
            params.from,
            params.kind,
            _totalSupply(params.pool),
            amountsOutRaw,
            swapFeeAmounts
        );
    }

    /**
     * @dev Preconditions: poolConfigBits, decimalScalingFactors, tokenRates in `poolData`.
     * Side effects: updates `_aggregateFeeAmounts` storage.
     * Note that this computes the aggregate total of the protocol fees and stores it, without emitting any events.
     * Splitting the fees and event emission occur during fee collection.
     * Should only be called in a non-reentrant context.
     *
     * @return totalSwapFeeAmountRaw Total swap fees raw (LP + aggregate protocol fees)
     * @return aggregateSwapFeeAmountRaw Sum of protocol and pool creator fees raw
     */
    function _computeAndChargeAggregateSwapFees(
        PoolData memory poolData,
        uint256 totalSwapFeeAmountScaled18,
        address pool,
        IERC20 token,
        uint256 index
    ) internal returns (uint256 totalSwapFeeAmountRaw, uint256 aggregateSwapFeeAmountRaw) {
        // If totalSwapFeeAmountScaled18 equals zero, no need to charge anything.
        if (totalSwapFeeAmountScaled18 > 0) {
            // The total swap fee does not go into the pool; amountIn does, and the raw fee at this point does not
            // modify it. Given that all of the fee may belong to the pool creator (i.e. outside pool balances),
            // we round down to protect the invariant.

            totalSwapFeeAmountRaw = totalSwapFeeAmountScaled18.toRawUndoRateRoundDown(
                poolData.decimalScalingFactors[index],
                poolData.tokenRates[index]
            );

            // Aggregate fees are not charged in Recovery Mode, but we still calculate and return the raw total swap
            // fee above for off-chain reporting purposes.
            if (poolData.poolConfigBits.isPoolInRecoveryMode() == false) {
                uint256 aggregateSwapFeePercentage = poolData.poolConfigBits.getAggregateSwapFeePercentage();

                // We have already calculated raw total fees rounding up.
                // Total fees = LP fees + aggregate fees, so by rounding aggregate fees down we round the fee split in
                // the LPs' favor, in turn increasing token balances and the pool invariant.
                aggregateSwapFeeAmountRaw = totalSwapFeeAmountRaw.mulDown(aggregateSwapFeePercentage);

                // Ensure we can never charge more than the total swap fee.
                if (aggregateSwapFeeAmountRaw > totalSwapFeeAmountRaw) {
                    revert ProtocolFeesExceedTotalCollected();
                }

                // Both Swap and Yield fees are stored together in a PackedTokenBalance.
                // We have designated "Raw" the derived half for Swap fee storage.
                bytes32 currentPackedBalance = _aggregateFeeAmounts[pool][token];
                _aggregateFeeAmounts[pool][token] = currentPackedBalance.setBalanceRaw(
                    currentPackedBalance.getBalanceRaw() + aggregateSwapFeeAmountRaw
                );
            }
        }
    }

    /*******************************************************************************
                                    Pool Information
    *******************************************************************************/

    /// @inheritdoc IVaultMain
    function getPoolTokenCountAndIndexOfToken(
        address pool,
        IERC20 token
    ) external view withRegisteredPool(pool) returns (uint256, uint256) {
        IERC20[] memory poolTokens = _poolTokens[pool];

        uint256 index = _findTokenIndex(poolTokens, token);

        return (poolTokens.length, index);
    }

    /*******************************************************************************
                                 Balancer Pool Tokens
    *******************************************************************************/

    /// @inheritdoc IVaultMain
    function transfer(address owner, address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, owner, to, amount);
        return true;
    }

    /// @inheritdoc IVaultMain
    function transferFrom(address spender, address from, address to, uint256 amount) external returns (bool) {
        _spendAllowance(msg.sender, from, spender, amount);
        _transfer(msg.sender, from, to, amount);
        return true;
    }

    /*******************************************************************************
                                  ERC4626 Buffers
    *******************************************************************************/

    /// @inheritdoc IVaultMain
    function erc4626BufferWrapOrUnwrap(
        BufferWrapOrUnwrapParams memory params
    )
        external
        onlyWhenUnlocked
        whenVaultBuffersAreNotPaused
        withInitializedBuffer(params.wrappedToken)
        nonReentrant
        returns (uint256 amountCalculatedRaw, uint256 amountInRaw, uint256 amountOutRaw)
    {
        IERC20 underlyingToken = IERC20(params.wrappedToken.asset());
        _ensureCorrectBufferAsset(params.wrappedToken, address(underlyingToken));

        _ensureValidWrapAmount(params.wrappedToken, params.amountGivenRaw);

        if (params.direction == WrappingDirection.UNWRAP) {
            bytes32 bufferBalances;
            (amountInRaw, amountOutRaw, bufferBalances) = _unwrapWithBuffer(
                params.kind,
                underlyingToken,
                params.wrappedToken,
                params.amountGivenRaw
            );
            emit Unwrap(params.wrappedToken, amountInRaw, amountOutRaw, bufferBalances);
        } else {
            bytes32 bufferBalances;
            (amountInRaw, amountOutRaw, bufferBalances) = _wrapWithBuffer(
                params.kind,
                underlyingToken,
                params.wrappedToken,
                params.amountGivenRaw
            );
            emit Wrap(params.wrappedToken, amountInRaw, amountOutRaw, bufferBalances);
        }

        if (params.kind == SwapKind.EXACT_IN) {
            if (amountOutRaw < params.limitRaw) {
                revert SwapLimit(amountOutRaw, params.limitRaw);
            }
            amountCalculatedRaw = amountOutRaw;
        } else {
            if (amountInRaw > params.limitRaw) {
                revert SwapLimit(amountInRaw, params.limitRaw);
            }
            amountCalculatedRaw = amountInRaw;
        }

        _ensureValidWrapAmount(params.wrappedToken, amountCalculatedRaw);
    }

    // If amount is too small, rounding issues can be introduced that favor the user and can leak value
    // from the buffer.
    // _MINIMUM_WRAP_AMOUNT prevents it. Most tokens have protections against it already; this is just an extra layer
    // of security.
    function _ensureValidWrapAmount(IERC4626 wrappedToken, uint256 amount) private view {
        if (amount < _MINIMUM_WRAP_AMOUNT) {
            revert WrapAmountTooSmall(wrappedToken);
        }
    }

    /**
     * @dev If the buffer has enough liquidity, it uses the internal ERC4626 buffer to perform the wrap
     * operation without any external calls. If not, it wraps the assets needed to fulfill the trade + the imbalance
     * of assets in the buffer, so that the buffer is rebalanced at the end of the operation.
     *
     * Updates `_reservesOf` and token deltas in storage.
     */
    function _wrapWithBuffer(
        SwapKind kind,
        IERC20 underlyingToken,
        IERC4626 wrappedToken,
        uint256 amountGiven
    ) internal returns (uint256 amountInUnderlying, uint256 amountOutWrapped, bytes32 bufferBalances) {
        if (kind == SwapKind.EXACT_IN) {
            // EXACT_IN wrap, so AmountGiven is an underlying amount. `deposit` is the ERC4626 operation that receives
            // an underlying amount in and calculates the wrapped amount out with the correct rounding. 1 wei is
            // removed from amountGiven to compensate for any rate manipulation. Also, 1 wei is removed from the
            // preview result to compensate for any rounding imprecision, so that the buffer does not leak value.
            (amountInUnderlying, amountOutWrapped) = (amountGiven, wrappedToken.previewDeposit(amountGiven - 1) - 1);
        } else {
            // EXACT_OUT wrap, so AmountGiven is a wrapped amount. `mint` is the ERC4626 operation that receives a
            // wrapped amount out and calculates the underlying amount in with the correct rounding. 1 wei is
            // added to amountGiven to compensate for any rate manipulation. Also, 1 wei is added to the
            // preview result to compensate for any rounding imprecision, so that the buffer does not leak value.
            (amountInUnderlying, amountOutWrapped) = (wrappedToken.previewMint(amountGiven + 1) + 1, amountGiven);
        }

        bufferBalances = _bufferTokenBalances[wrappedToken];

        // If it's a query, the Vault may not have enough underlying tokens to wrap. Since in a query we do not expect
        // the sender to pay for underlying tokens to wrap upfront, return the calculated amount without checking for
        // the imbalance.
        if (_isQueryContext()) {
            return (amountInUnderlying, amountOutWrapped, bufferBalances);
        }

        if (bufferBalances.getBalanceDerived() >= amountOutWrapped) {
            // The buffer has enough liquidity to facilitate the wrap without making an external call.
            uint256 newDerivedBalance;
            unchecked {
                // We have verified above that this is safe to do unchecked.
                newDerivedBalance = bufferBalances.getBalanceDerived() - amountOutWrapped;
            }

            bufferBalances = PackedTokenBalance.toPackedBalance(
                bufferBalances.getBalanceRaw() + amountInUnderlying,
                newDerivedBalance
            );
            _bufferTokenBalances[wrappedToken] = bufferBalances;
        } else {
            // The buffer does not have enough liquidity to facilitate the wrap without making an external call.
            // We wrap the user's tokens via an external call and additionally rebalance the buffer if it has an
            // imbalance of underlying tokens.

            // Expected amount of underlying deposited into the wrapper protocol.
            uint256 vaultUnderlyingDeltaHint;
            // Expected amount of wrapped minted by the wrapper protocol.
            uint256 vaultWrappedDeltaHint;

            if (kind == SwapKind.EXACT_IN) {
                // EXACT_IN requires the exact amount of underlying tokens to be deposited, so we call deposit.
                // The amount of underlying tokens to deposit is the necessary amount to fulfill the trade
                // (amountInUnderlying), plus the amount needed to leave the buffer rebalanced 50/50 at the end
                // (bufferUnderlyingImbalance). `bufferUnderlyingImbalance` may be positive if the buffer has an excess
                // of underlying, or negative if the buffer has an excess of wrapped tokens. `vaultUnderlyingDeltaHint`
                // will always be a positive number, because if `abs(bufferUnderlyingImbalance) > amountInUnderlying`
                // and `bufferUnderlyingImbalance < 0`, it means the buffer has enough liquidity to fulfill the trade
                // (i.e. `bufferBalances.getBalanceDerived() >= amountOutWrapped`).
                int256 bufferUnderlyingImbalance = bufferBalances.getBufferUnderlyingImbalance(wrappedToken);
                vaultUnderlyingDeltaHint = (amountInUnderlying.toInt256() + bufferUnderlyingImbalance).toUint256();
                underlyingToken.forceApprove(address(wrappedToken), vaultUnderlyingDeltaHint);
                vaultWrappedDeltaHint = wrappedToken.deposit(vaultUnderlyingDeltaHint, address(this));
            } else {
                // EXACT_OUT requires the exact amount of wrapped tokens to be minted, so we call mint.
                // The amount of wrapped tokens to mint is the amount necessary to fulfill the trade
                // (amountOutWrapped), minus the excess amount of wrapped tokens in the buffer (bufferWrappedImbalance).
                // `bufferWrappedImbalance` may be positive if buffer has an excess of wrapped assets or negative if
                // the buffer has an excess of underlying assets. `vaultWrappedDeltaHint` will always be a positive
                // number, because if `abs(bufferWrappedImbalance) > amountOutWrapped` and `bufferWrappedImbalance > 0`,
                // it means the buffer has enough liquidity to fulfill the trade
                // (i.e. `bufferBalances.getBalanceDerived() >= amountOutWrapped`).
                int256 bufferWrappedImbalance = bufferBalances.getBufferWrappedImbalance(wrappedToken);
                vaultWrappedDeltaHint = (amountOutWrapped.toInt256() - bufferWrappedImbalance).toUint256();

                // For Wrap ExactOut, we also need to calculate `vaultUnderlyingDeltaHint` before the mint operation,
                // to approve the transfer of underlying tokens to the wrapper protocol.
                vaultUnderlyingDeltaHint = wrappedToken.previewMint(vaultWrappedDeltaHint);

                // The mint operation returns exactly `vaultWrappedDeltaHint` shares. To do so, it withdraws underlying
                // tokens from the Vault and returns the shares. So, the Vault needs to approve the transfer of
                // underlying tokens to the wrapper.
                underlyingToken.forceApprove(address(wrappedToken), vaultUnderlyingDeltaHint);

                vaultUnderlyingDeltaHint = wrappedToken.mint(vaultWrappedDeltaHint, address(this));
            }

            // Remove approval, in case deposit/mint consumed less tokens than we approved.
            // E.g., A malicious wrapper could not consume all of the underlying tokens and use the Vault approval to
            // drain the Vault.
            underlyingToken.forceApprove(address(wrappedToken), 0);

            // Check if the Vault's underlying balance decreased by `vaultUnderlyingDeltaHint` and the Vault's
            // wrapped balance increased by `vaultWrappedDeltaHint`. If not, it reverts.
            _settleWrap(underlyingToken, IERC20(wrappedToken), vaultUnderlyingDeltaHint, vaultWrappedDeltaHint);

            // In a wrap operation, the buffer underlying balance increases by `amountInUnderlying` (the amount that
            // the caller deposited into the buffer) and decreases by `vaultUnderlyingDeltaHint` (the amount of
            // underlying deposited by the buffer into the wrapper protocol). Conversely, the buffer wrapped balance
            // decreases by `amountOutWrapped` (the amount of wrapped tokens that the buffer returned to the caller)
            // and increases by `vaultWrappedDeltaHint` (the amount of wrapped tokens minted by the wrapper protocol).
            bufferBalances = PackedTokenBalance.toPackedBalance(
                bufferBalances.getBalanceRaw() + amountInUnderlying - vaultUnderlyingDeltaHint,
                bufferBalances.getBalanceDerived() + vaultWrappedDeltaHint - amountOutWrapped
            );
            _bufferTokenBalances[wrappedToken] = bufferBalances;
        }

        _takeDebt(underlyingToken, amountInUnderlying);
        _supplyCredit(wrappedToken, amountOutWrapped);
    }

    /**
     * @dev If the buffer has enough liquidity, it uses the internal ERC4626 buffer to perform the unwrap
     * operation without any external calls. If not, it unwraps the assets needed to fulfill the trade + the imbalance
     * of assets in the buffer, so that the buffer is rebalanced at the end of the operation.
     *
     * Updates `_reservesOf` and token deltas in storage.
     */
    function _unwrapWithBuffer(
        SwapKind kind,
        IERC20 underlyingToken,
        IERC4626 wrappedToken,
        uint256 amountGiven
    ) internal returns (uint256 amountInWrapped, uint256 amountOutUnderlying, bytes32 bufferBalances) {
        if (kind == SwapKind.EXACT_IN) {
            // EXACT_IN unwrap, so AmountGiven is a wrapped amount. `redeem` is the ERC4626 operation that receives a
            // wrapped amount in and calculates the underlying amount out with the correct rounding. 1 wei is removed
            // from amountGiven to compensate for any rate manipulation. Also, 1 wei is removed from the preview result
            // to compensate for any rounding imprecision, so that the buffer does not leak value.
            (amountInWrapped, amountOutUnderlying) = (amountGiven, wrappedToken.previewRedeem(amountGiven - 1) - 1);
        } else {
            // EXACT_OUT unwrap, so AmountGiven is an underlying amount. `withdraw` is the ERC4626 operation that
            // receives an underlying amount out and calculates the wrapped amount in with the correct rounding. 1 wei
            // is added to amountGiven to compensate for any rate manipulation. Also, 1 wei is added to the preview
            // result to compensate for any rounding imprecision, so that the buffer does not leak value.
            (amountInWrapped, amountOutUnderlying) = (wrappedToken.previewWithdraw(amountGiven + 1) + 1, amountGiven);
        }

        bufferBalances = _bufferTokenBalances[wrappedToken];

        // If it's a query, the Vault may not have enough wrapped tokens to unwrap. Since in a query we do not expect
        // the sender to pay for wrapped tokens to unwrap upfront, return the calculated amount without checking for
        // the imbalance.
        if (_isQueryContext()) {
            return (amountInWrapped, amountOutUnderlying, bufferBalances);
        }

        if (bufferBalances.getBalanceRaw() >= amountOutUnderlying) {
            // The buffer has enough liquidity to facilitate the wrap without making an external call.
            uint256 newRawBalance;
            unchecked {
                // We have verified above that this is safe to do unchecked.
                newRawBalance = bufferBalances.getBalanceRaw() - amountOutUnderlying;
            }
            bufferBalances = PackedTokenBalance.toPackedBalance(
                newRawBalance,
                bufferBalances.getBalanceDerived() + amountInWrapped
            );
            _bufferTokenBalances[wrappedToken] = bufferBalances;
        } else {
            // The buffer does not have enough liquidity to facilitate the unwrap without making an external call.
            // We unwrap the user's tokens via an external call and additionally rebalance the buffer if it has an
            // imbalance of wrapped tokens.

            // Expected amount of underlying withdrawn from the wrapper protocol.
            uint256 vaultUnderlyingDeltaHint;
            // Expected amount of wrapped burned by the wrapper protocol.
            uint256 vaultWrappedDeltaHint;

            if (kind == SwapKind.EXACT_IN) {
                // EXACT_IN requires the exact amount of wrapped tokens to be unwrapped, so we call redeem. The amount
                // of wrapped tokens to redeem is the amount necessary to fulfill the trade (amountInWrapped), plus the
                // amount needed to leave the buffer rebalanced 50/50 at the end (bufferWrappedImbalance).
                // `bufferWrappedImbalance` may be positive if the buffer has an excess of wrapped, or negative if the
                // buffer has an excess of underlying tokens. `vaultWrappedDeltaHint` will always be a positive number,
                // because if `abs(bufferWrappedImbalance) > amountInWrapped` and `bufferWrappedImbalance < 0`, it
                // means the buffer has enough liquidity to fulfill the trade
                // (i.e. `bufferBalances.getBalanceRaw() >= amountOutUnderlying`).
                int256 bufferWrappedImbalance = bufferBalances.getBufferWrappedImbalance(wrappedToken);
                vaultWrappedDeltaHint = (amountInWrapped.toInt256() + bufferWrappedImbalance).toUint256();
                vaultUnderlyingDeltaHint = wrappedToken.redeem(vaultWrappedDeltaHint, address(this), address(this));
            } else {
                // EXACT_OUT requires the exact amount of underlying tokens to be returned, so we call withdraw.
                // The amount of underlying tokens to withdraw is the amount necessary to fulfill the trade
                // (amountOutUnderlying), minus the excess amount of underlying assets in the buffer
                // (bufferUnderlyingImbalance). `bufferUnderlyingImbalance` may be positive if the buffer has an excess
                // of underlying, or negative if the buffer has an excess of wrapped tokens. `vaultUnderlyingDeltaHint`
                // will always be a positive number, because if `abs(bufferUnderlyingImbalance) > amountOutUnderlying`
                // and `bufferUnderlyingImbalance > 0`, it means the buffer has enough liquidity to fulfill the trade
                // (i.e. `bufferBalances.getBalanceRaw() >= amountOutUnderlying`).
                int256 bufferUnderlyingImbalance = bufferBalances.getBufferUnderlyingImbalance(wrappedToken);
                vaultUnderlyingDeltaHint = (amountOutUnderlying.toInt256() - bufferUnderlyingImbalance).toUint256();
                vaultWrappedDeltaHint = wrappedToken.withdraw(vaultUnderlyingDeltaHint, address(this), address(this));
            }

            // Check if the Vault's underlying balance increased by `vaultUnderlyingDeltaHint` and the Vault's
            // wrapped balance decreased by `vaultWrappedDeltaHint`. If not, it reverts.
            _settleUnwrap(underlyingToken, IERC20(wrappedToken), vaultUnderlyingDeltaHint, vaultWrappedDeltaHint);

            // In an unwrap operation, the buffer underlying balance increases by `vaultUnderlyingDeltaHint` (the
            // amount of underlying withdrawn by the buffer from the wrapper protocol) and decreases by
            // `amountOutUnderlying` (the amount of underlying assets that the caller withdrawn from the buffer).
            // Conversely, the buffer wrapped balance increases by `amountInWrapped` (the amount of wrapped tokens that
            // the caller sent to the buffer) and decreases by `vaultWrappedDeltaHint` (the amount of wrapped tokens
            // burned by the wrapper protocol).
            bufferBalances = PackedTokenBalance.toPackedBalance(
                bufferBalances.getBalanceRaw() + vaultUnderlyingDeltaHint - amountOutUnderlying,
                bufferBalances.getBalanceDerived() + amountInWrapped - vaultWrappedDeltaHint
            );
            _bufferTokenBalances[wrappedToken] = bufferBalances;
        }

        _takeDebt(wrappedToken, amountInWrapped);
        _supplyCredit(underlyingToken, amountOutUnderlying);
    }

    /**
     * @notice Updates the reserves of the Vault after an ERC4626 wrap (deposit/mint) operation.
     * @dev If there are extra tokens in the Vault balances, these will be added to the reserves (which, in practice,
     * is equal to discarding such tokens). This approach avoids DoS attacks, when a frontrunner leaves vault balances
     * and reserves out of sync before a transaction starts.
     *
     * @param underlyingToken Underlying token of the ERC4626 wrapped token
     * @param wrappedToken ERC4626 wrapped token
     * @param underlyingDeltaHint Amount of underlying tokens the wrapper should have removed from the Vault
     * @param wrappedDeltaHint Amount of wrapped tokens the wrapper should have added to the Vault
     */
    function _settleWrap(
        IERC20 underlyingToken,
        IERC20 wrappedToken,
        uint256 underlyingDeltaHint,
        uint256 wrappedDeltaHint
    ) internal {
        // A wrap operation removes underlying tokens from the Vault, so the Vault's expected underlying balance after
        // the operation is `underlyingReservesBefore - underlyingDeltaHint`.
        uint256 expectedUnderlyingReservesAfter = _reservesOf[underlyingToken] - underlyingDeltaHint;

        // A wrap operation adds wrapped tokens to the Vault, so the Vault's expected wrapped balance after the
        // operation is `wrappedReservesBefore + wrappedDeltaHint`.
        uint256 expectedWrappedReservesAfter = _reservesOf[wrappedToken] + wrappedDeltaHint;

        _settleWrapUnwrap(underlyingToken, wrappedToken, expectedUnderlyingReservesAfter, expectedWrappedReservesAfter);
    }

    /**
     * @notice Updates the reserves of the Vault after an ERC4626 unwrap (withdraw/redeem) operation.
     * @dev If there are extra tokens in the Vault balances, these will be added to the reserves (which, in practice,
     * is equal to discarding such tokens). This approach avoids DoS attacks, when a frontrunner leaves vault balances
     * and state of reserves out of sync before a transaction starts.
     *
     * @param underlyingToken Underlying of ERC4626 wrapped token
     * @param wrappedToken ERC4626 wrapped token
     * @param underlyingDeltaHint Amount of underlying tokens supposedly added to the Vault
     * @param wrappedDeltaHint Amount of wrapped tokens supposedly removed from the Vault
     */
    function _settleUnwrap(
        IERC20 underlyingToken,
        IERC20 wrappedToken,
        uint256 underlyingDeltaHint,
        uint256 wrappedDeltaHint
    ) internal {
        // An unwrap operation adds underlying tokens to the Vault, so the Vault's expected underlying balance after
        // the operation is `underlyingReservesBefore + underlyingDeltaHint`.
        uint256 expectedUnderlyingReservesAfter = _reservesOf[underlyingToken] + underlyingDeltaHint;

        // An unwrap operation removes wrapped tokens from the Vault, so the Vault's expected wrapped balance after the
        // operation is `wrappedReservesBefore - wrappedDeltaHint`.
        uint256 expectedWrappedReservesAfter = _reservesOf[wrappedToken] - wrappedDeltaHint;

        _settleWrapUnwrap(underlyingToken, wrappedToken, expectedUnderlyingReservesAfter, expectedWrappedReservesAfter);
    }

    /**
     * @notice Updates the reserves of the Vault after an ERC4626 wrap/unwrap operation.
     * @dev If reserves of underlying or wrapped tokens are bigger than expected, the extra tokens will be discarded,
     * which avoids a possible DoS. However, if reserves are smaller than expected, it means that the wrapper didn't
     * respect the amount given and/or the amount calculated (informed by the wrapper operation and stored as a hint
     * variable), so the token is not ERC4626 compliant and the function should be reverted.
     *
     * @param underlyingToken Underlying of ERC4626 wrapped token
     * @param wrappedToken ERC4626 wrapped token
     * @param expectedUnderlyingReservesAfter Vault's expected reserves of underlying after the wrap/unwrap operation
     * @param expectedWrappedReservesAfter Vault's expected reserves of wrapped after the wrap/unwrap operation
     */
    function _settleWrapUnwrap(
        IERC20 underlyingToken,
        IERC20 wrappedToken,
        uint256 expectedUnderlyingReservesAfter,
        uint256 expectedWrappedReservesAfter
    ) internal {
        // Update the Vault's underlying reserves.
        uint256 underlyingBalancesAfter = underlyingToken.balanceOf(address(this));
        if (underlyingBalancesAfter < expectedUnderlyingReservesAfter) {
            // If Vault's underlying balance is smaller than expected, the Vault was drained and the operation should
            // revert. It may happen in different ways, depending on the wrap/unwrap operation:
            // * deposit: the wrapper didn't respect the exact amount in of underlying;
            // * mint: the underlying amount subtracted from the Vault is bigger than wrapper's calculated amount in;
            // * withdraw: the wrapper didn't respect the exact amount out of underlying;
            // * redeem: the underlying amount added to the Vault is smaller than wrapper's calculated amount out.
            revert NotEnoughUnderlying(
                IERC4626(address(wrappedToken)),
                expectedUnderlyingReservesAfter,
                underlyingBalancesAfter
            );
        }
        // Update the Vault's underlying reserves, discarding any unexpected imbalance of tokens (difference between
        // actual and expected vault balance).
        _reservesOf[underlyingToken] = underlyingBalancesAfter;

        // Update the Vault's wrapped reserves.
        uint256 wrappedBalancesAfter = wrappedToken.balanceOf(address(this));
        if (wrappedBalancesAfter < expectedWrappedReservesAfter) {
            // If the Vault's wrapped balance is smaller than expected, the Vault was drained and the operation should
            // revert. It may happen in different ways, depending on the wrap/unwrap operation:
            // * deposit: the wrapped amount added to the Vault is smaller than wrapper's calculated amount out;
            // * mint: the wrapper didn't respect the exact amount out of wrapped;
            // * withdraw: the wrapped amount subtracted from the Vault is bigger than wrapper's calculated amount in;
            // * redeem: the wrapper didn't respect the exact amount in of wrapped.
            revert NotEnoughWrapped(
                IERC4626(address(wrappedToken)),
                expectedWrappedReservesAfter,
                wrappedBalancesAfter
            );
        }
        // Update the Vault's wrapped reserves, discarding any unexpected surplus of tokens (difference between
        // the Vault's actual and expected balances).
        _reservesOf[wrappedToken] = wrappedBalancesAfter;
    }

    // Minimum token value in or out (applied to scaled18 values), enforced as a security measure to block potential
    // exploitation of rounding errors. This is called in the context of adding or removing liquidity, so zero is
    // allowed to support single-token operations.
    function _ensureValidTradeAmount(uint256 tradeAmount) internal view {
        if (tradeAmount != 0) {
            _ensureValidSwapAmount(tradeAmount);
        }
    }

    // Minimum token value in or out (applied to scaled18 values), enforced as a security measure to block potential
    // exploitation of rounding errors. This is called in the swap context, so zero is not a valid amount. Note that
    // since this is applied to the scaled amount, the corresponding minimum raw amount will vary according to token
    // decimals. The math functions are called with scaled amounts, and the magnitude of the minimum values is based
    // on the maximum error, so this is fine. Trying to adjust for decimals would add complexity and significant gas
    // to the critical path, so we don't do it. (Note that very low-decimal tokens don't work well in AMMs generally;
    // this is another reason to avoid them.)
    function _ensureValidSwapAmount(uint256 tradeAmount) internal view {
        if (tradeAmount < _MINIMUM_TRADE_AMOUNT) {
            revert TradeAmountTooSmall();
        }
    }

    /*******************************************************************************
                                     Miscellaneous
    *******************************************************************************/

    /// @inheritdoc IVaultMain
    function getVaultExtension() external view returns (address) {
        return _implementation();
    }

    /**
     * @inheritdoc Proxy
     * @dev Returns the VaultExtension contract, to which fallback requests are forwarded.
     */
    function _implementation() internal view override returns (address) {
        return address(_vaultExtension);
    }

    /*******************************************************************************
                                     Default handlers
    *******************************************************************************/

    receive() external payable {
        revert CannotReceiveEth();
    }

    // solhint-disable no-complex-fallback

    /**
     * @inheritdoc Proxy
     * @dev Override proxy implementation of `fallback` to disallow incoming ETH transfers.
     * This function actually returns whatever the VaultExtension does when handling the request.
     */
    fallback() external payable override {
        if (msg.value > 0) {
            revert CannotReceiveEth();
        }

        _fallback();
    }
}


// File: contracts/VaultCommon.sol

// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.24;

import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { ISwapFeePercentageBounds } from "@balancer-labs/v3-interfaces/contracts/vault/ISwapFeePercentageBounds.sol";
import { PoolData, Rounding } from "@balancer-labs/v3-interfaces/contracts/vault/VaultTypes.sol";
import { IVaultErrors } from "@balancer-labs/v3-interfaces/contracts/vault/IVaultErrors.sol";
import { IVaultEvents } from "@balancer-labs/v3-interfaces/contracts/vault/IVaultEvents.sol";

import { StorageSlotExtension } from "@balancer-labs/v3-solidity-utils/contracts/openzeppelin/StorageSlotExtension.sol";
import { EVMCallModeHelpers } from "@balancer-labs/v3-solidity-utils/contracts/helpers/EVMCallModeHelpers.sol";
import { PackedTokenBalance } from "@balancer-labs/v3-solidity-utils/contracts/helpers/PackedTokenBalance.sol";
import { ScalingHelpers } from "@balancer-labs/v3-solidity-utils/contracts/helpers/ScalingHelpers.sol";
import {
    ReentrancyGuardTransient
} from "@balancer-labs/v3-solidity-utils/contracts/openzeppelin/ReentrancyGuardTransient.sol";
import {
    TransientStorageHelpers
} from "@balancer-labs/v3-solidity-utils/contracts/helpers/TransientStorageHelpers.sol";

import { VaultStateBits, VaultStateLib } from "./lib/VaultStateLib.sol";
import { PoolConfigBits, PoolConfigLib } from "./lib/PoolConfigLib.sol";
import { ERC20MultiToken } from "./token/ERC20MultiToken.sol";
import { PoolDataLib } from "./lib/PoolDataLib.sol";
import { VaultStorage } from "./VaultStorage.sol";

/**
 * @notice Functions and modifiers shared between the main Vault and its extension contracts.
 * @dev This contract contains common utilities in the inheritance chain that require storage to work,
 * and will be required in both the main Vault and its extensions.
 */
abstract contract VaultCommon is IVaultEvents, IVaultErrors, VaultStorage, ReentrancyGuardTransient, ERC20MultiToken {
    using PoolConfigLib for PoolConfigBits;
    using VaultStateLib for VaultStateBits;
    using SafeCast for *;
    using TransientStorageHelpers for *;
    using StorageSlotExtension for *;
    using PoolDataLib for PoolData;

    /*******************************************************************************
                              Transient Accounting
    *******************************************************************************/

    /**
     * @dev This modifier ensures that the function it modifies can only be called
     * when a tab has been opened.
     */
    modifier onlyWhenUnlocked() {
        _ensureUnlocked();
        _;
    }

    function _ensureUnlocked() internal view {
        if (_isUnlocked().tload() == false) {
            revert VaultIsNotUnlocked();
        }
    }

    /**
     * @notice Expose the state of the Vault's reentrancy guard.
     * @return True if the Vault is currently executing a nonReentrant function
     */
    function reentrancyGuardEntered() public view returns (bool) {
        return _reentrancyGuardEntered();
    }

    /**
     * @notice Records the `credit` for a given token.
     * @param token The ERC20 token for which the 'credit' will be accounted
     * @param credit The amount of `token` supplied to the Vault in favor of the caller
     */
    function _supplyCredit(IERC20 token, uint256 credit) internal {
        _accountDelta(token, -credit.toInt256());
    }

    /**
     * @notice Records the `debt` for a given token.
     * @param token The ERC20 token for which the `debt` will be accounted
     * @param debt The amount of `token` taken from the Vault in favor of the caller
     */
    function _takeDebt(IERC20 token, uint256 debt) internal {
        _accountDelta(token, debt.toInt256());
    }

    /**
     * @dev Accounts the delta for the given token. A positive delta represents debt,
     * while a negative delta represents surplus.
     *
     * @param token The ERC20 token for which the delta is being accounted
     * @param delta The difference in the token balance
     * Positive indicates a debit or a decrease in Vault's tokens,
     * negative indicates a credit or an increase in Vault's tokens.
     */
    function _accountDelta(IERC20 token, int256 delta) internal {
        // If the delta is zero, there's nothing to account for.
        if (delta == 0) return;

        // Get the current recorded delta for this token.
        int256 current = _tokenDeltas().tGet(token);

        // Calculate the new delta after accounting for the change.
        int256 next = current + delta;

        if (next == 0) {
            // If the resultant delta becomes zero after this operation,
            // decrease the count of non-zero deltas.
            _nonZeroDeltaCount().tDecrement();
        } else if (current == 0) {
            // If there was no previous delta (i.e., it was zero) and now we have one,
            // increase the count of non-zero deltas.
            _nonZeroDeltaCount().tIncrement();
        }

        // Update the delta for this token.
        _tokenDeltas().tSet(token, next);
    }

    /*******************************************************************************
                                    Vault Pausing
    *******************************************************************************/

    /// @dev Modifier to make a function callable only when the Vault is not paused.
    modifier whenVaultNotPaused() {
        _ensureVaultNotPaused();
        _;
    }

    /// @dev Reverts if the Vault is paused.
    function _ensureVaultNotPaused() internal view {
        if (_isVaultPaused()) {
            revert VaultPaused();
        }
    }

    /// @dev Reverts if the Vault or the given pool are paused.
    function _ensureUnpaused(address pool) internal view {
        _ensureVaultNotPaused();
        _ensurePoolNotPaused(pool);
    }

    /**
     * @dev For gas efficiency, storage is only read before `_vaultBufferPeriodEndTime`. Once we're past that
     * timestamp, the expression short-circuits false, and the Vault is permanently unpaused.
     */
    function _isVaultPaused() internal view returns (bool) {
        // solhint-disable-next-line not-rely-on-time
        return block.timestamp <= _vaultBufferPeriodEndTime && _vaultStateBits.isVaultPaused();
    }

    /*******************************************************************************
                                     Pool Pausing
    *******************************************************************************/

    /// @dev Reverts if the pool is paused.
    function _ensurePoolNotPaused(address pool) internal view {
        if (_isPoolPaused(pool)) {
            revert PoolPaused(pool);
        }
    }

    /// @dev Check both the flag and timestamp to determine whether the pool is paused.
    function _isPoolPaused(address pool) internal view returns (bool) {
        (bool paused, ) = _getPoolPausedState(pool);

        return paused;
    }

    /// @dev Lowest level routine that plucks only the minimum necessary parts from storage.
    function _getPoolPausedState(address pool) internal view returns (bool, uint32) {
        PoolConfigBits config = _poolConfigBits[pool];

        bool isPoolPaused = config.isPoolPaused();
        uint32 pauseWindowEndTime = config.getPauseWindowEndTime();

        // Use the Vault's buffer period.
        // solhint-disable-next-line not-rely-on-time
        return (isPoolPaused && block.timestamp <= pauseWindowEndTime + _vaultBufferPeriodDuration, pauseWindowEndTime);
    }

    /*******************************************************************************
                                     Buffer Pausing
    *******************************************************************************/
    /// @dev Modifier to make a function callable only when vault buffers are not paused.
    modifier whenVaultBuffersAreNotPaused() {
        _ensureVaultBuffersAreNotPaused();
        _;
    }

    /// @dev Reverts if vault buffers are paused.
    function _ensureVaultBuffersAreNotPaused() internal view {
        if (_vaultStateBits.areBuffersPaused()) {
            revert VaultBuffersArePaused();
        }
    }

    /*******************************************************************************
                            Pool Registration and Initialization
    *******************************************************************************/

    /// @dev Reverts unless `pool` is a registered Pool.
    modifier withRegisteredPool(address pool) {
        _ensureRegisteredPool(pool);
        _;
    }

    /// @dev Reverts unless `pool` is an initialized Pool.
    modifier withInitializedPool(address pool) {
        _ensureInitializedPool(pool);
        _;
    }

    function _ensureRegisteredPool(address pool) internal view {
        if (!_isPoolRegistered(pool)) {
            revert PoolNotRegistered(pool);
        }
    }

    /// @dev See `isPoolRegistered`
    function _isPoolRegistered(address pool) internal view returns (bool) {
        PoolConfigBits config = _poolConfigBits[pool];
        return config.isPoolRegistered();
    }

    function _ensureInitializedPool(address pool) internal view {
        if (!_isPoolInitialized(pool)) {
            revert PoolNotInitialized(pool);
        }
    }

    /// @dev See `isPoolInitialized`
    function _isPoolInitialized(address pool) internal view returns (bool) {
        PoolConfigBits config = _poolConfigBits[pool];
        return config.isPoolInitialized();
    }

    /*******************************************************************************
                          Buffer Initialization & Validation
    *******************************************************************************/

    modifier withInitializedBuffer(IERC4626 wrappedToken) {
        _ensureBufferInitialized(wrappedToken);
        _;
    }

    function _ensureBufferInitialized(IERC4626 wrappedToken) internal view {
        if (_bufferAssets[wrappedToken] == address(0)) {
            revert BufferNotInitialized(wrappedToken);
        }
    }

    /**
     * @dev This assumes `underlyingToken` is non-zero; should be called by functions that have already ensured the
     * buffer has been initialized (e.g., those protected by `withInitializedBuffer`).
     */
    function _ensureCorrectBufferAsset(IERC4626 wrappedToken, address underlyingToken) internal view {
        if (_bufferAssets[wrappedToken] != underlyingToken) {
            // Asset was changed since the buffer was initialized.
            revert WrongUnderlyingToken(wrappedToken, underlyingToken);
        }
    }

    /*******************************************************************************
                                    Pool Information
    *******************************************************************************/

    /**
     * @dev Packs and sets the raw and live balances of a Pool's tokens to the current values in poolData.balancesRaw
     * and poolData.liveBalances in the same storage slot.
     */
    function _writePoolBalancesToStorage(address pool, PoolData memory poolData) internal {
        mapping(uint256 tokenIndex => bytes32 packedTokenBalance) storage poolBalances = _poolTokenBalances[pool];

        for (uint256 i = 0; i < poolData.balancesRaw.length; ++i) {
            // We assume all newBalances are properly ordered.
            poolBalances[i] = PackedTokenBalance.toPackedBalance(
                poolData.balancesRaw[i],
                poolData.balancesLiveScaled18[i]
            );
        }
    }

    /**
     * @dev Fill in PoolData, including paying protocol yield fees and computing final raw and live balances.
     * In normal operation, we update both balances and fees together. However, while Recovery Mode is enabled,
     * we cannot track yield fees, as that would involve making external calls that could fail and block withdrawals.
     *
     * Therefore, disabling Recovery Mode requires writing *only* the balances to storage, so we still need this
     * as a separate function. It is normally called by `_loadPoolDataUpdatingBalancesAndYieldFees`, but in the
     * Recovery Mode special case, it is called separately, with the result passed into `_writePoolBalancesToStorage`.
     */
    function _loadPoolData(address pool, Rounding roundingDirection) internal view returns (PoolData memory poolData) {
        poolData.load(
            _poolTokenBalances[pool],
            _poolConfigBits[pool],
            _poolTokenInfo[pool],
            _poolTokens[pool],
            roundingDirection
        );
    }

    /**
     * @dev Fill in PoolData, including paying protocol yield fees and computing final raw and live balances.
     * This function modifies protocol fees and balance storage. Out of an abundance of caution, since `_loadPoolData`
     * makes external calls, we are making anything that calls it and then modifies storage non-reentrant.
     * Side effects: updates `_aggregateFeeAmounts` and `_poolTokenBalances` in storage.
     */
    function _loadPoolDataUpdatingBalancesAndYieldFees(
        address pool,
        Rounding roundingDirection
    ) internal nonReentrant returns (PoolData memory poolData) {
        // Initialize poolData with base information for subsequent calculations.
        poolData.load(
            _poolTokenBalances[pool],
            _poolConfigBits[pool],
            _poolTokenInfo[pool],
            _poolTokens[pool],
            roundingDirection
        );

        PoolDataLib.syncPoolBalancesAndFees(poolData, _poolTokenBalances[pool], _aggregateFeeAmounts[pool]);
    }

    /**
     * @dev Updates the raw and live balance of a given token in poolData, scaling the given raw balance by both decimal
     * and token rates, and rounding the result in the given direction. Assumes scaling factors and rates are current
     * in PoolData.
     */
    function _updateRawAndLiveTokenBalancesInPoolData(
        PoolData memory poolData,
        uint256 newRawBalance,
        Rounding roundingDirection,
        uint256 tokenIndex
    ) internal pure returns (uint256) {
        poolData.balancesRaw[tokenIndex] = newRawBalance;

        function(uint256, uint256, uint256) internal pure returns (uint256) _upOrDown = roundingDirection ==
            Rounding.ROUND_UP
            ? ScalingHelpers.toScaled18ApplyRateRoundUp
            : ScalingHelpers.toScaled18ApplyRateRoundDown;

        poolData.balancesLiveScaled18[tokenIndex] = _upOrDown(
            newRawBalance,
            poolData.decimalScalingFactors[tokenIndex],
            poolData.tokenRates[tokenIndex]
        );

        return _upOrDown(newRawBalance, poolData.decimalScalingFactors[tokenIndex], poolData.tokenRates[tokenIndex]);
    }

    function _setStaticSwapFeePercentage(address pool, uint256 swapFeePercentage) internal {
        // These cannot be called during pool construction. Pools must be deployed first, then registered.
        if (swapFeePercentage < ISwapFeePercentageBounds(pool).getMinimumSwapFeePercentage()) {
            revert SwapFeePercentageTooLow();
        }

        if (swapFeePercentage > ISwapFeePercentageBounds(pool).getMaximumSwapFeePercentage()) {
            revert SwapFeePercentageTooHigh();
        }

        // The library also checks that the percentage is <= FP(1), regardless of what the pool defines.
        _poolConfigBits[pool] = _poolConfigBits[pool].setStaticSwapFeePercentage(swapFeePercentage);

        emit SwapFeePercentageChanged(pool, swapFeePercentage);
    }

    /// @dev Find the index of a token in a token array. Reverts if not found.
    function _findTokenIndex(IERC20[] memory tokens, IERC20 token) internal pure returns (uint256) {
        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i] == token) {
                return i;
            }
        }

        revert TokenNotRegistered(token);
    }

    /*******************************************************************************
                                    Recovery Mode
    *******************************************************************************/

    /// @dev Place on functions that may only be called when the associated pool is in recovery mode.
    modifier onlyInRecoveryMode(address pool) {
        _ensurePoolInRecoveryMode(pool);
        _;
    }

    /// @dev Reverts if the pool is not in recovery mode.
    function _ensurePoolInRecoveryMode(address pool) internal view {
        if (!_isPoolInRecoveryMode(pool)) {
            revert PoolNotInRecoveryMode(pool);
        }
    }

    /**
     * @notice Checks whether a pool is in recovery mode.
     * @param pool Address of the pool to check
     * @return inRecoveryMode True if the pool is in recovery mode, false otherwise
     */
    function _isPoolInRecoveryMode(address pool) internal view returns (bool) {
        return _poolConfigBits[pool].isPoolInRecoveryMode();
    }

    function _isQueryContext() internal view returns (bool) {
        return EVMCallModeHelpers.isStaticCall() && _vaultStateBits.isQueryDisabled() == false;
    }
}


// File: contracts/VaultGuard.sol

// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.24;

import { IVaultErrors } from "@balancer-labs/v3-interfaces/contracts/vault/IVaultErrors.sol";
import { IVault } from "@balancer-labs/v3-interfaces/contracts/vault/IVault.sol";

/// @notice Contract that shares the modifier `onlyVault`.
contract VaultGuard {
    IVault internal immutable _vault;

    constructor(IVault vault) {
        _vault = vault;
    }

    modifier onlyVault() {
        _ensureOnlyVault();
        _;
    }

    function _ensureOnlyVault() private view {
        if (msg.sender != address(_vault)) {
            revert IVaultErrors.SenderIsNotVault(msg.sender);
        }
    }
}


// File: contracts/VaultStorage.sol

// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.24;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { IProtocolFeeController } from "@balancer-labs/v3-interfaces/contracts/vault/IProtocolFeeController.sol";
import { IVaultExtension } from "@balancer-labs/v3-interfaces/contracts/vault/IVaultExtension.sol";
import { IAuthorizer } from "@balancer-labs/v3-interfaces/contracts/vault/IAuthorizer.sol";
import { IHooks } from "@balancer-labs/v3-interfaces/contracts/vault/IHooks.sol";
import "@balancer-labs/v3-interfaces/contracts/vault/VaultTypes.sol";

import { StorageSlotExtension } from "@balancer-labs/v3-solidity-utils/contracts/openzeppelin/StorageSlotExtension.sol";
import {
    TransientStorageHelpers,
    TokenDeltaMappingSlotType,
    UintToAddressToBooleanMappingSlot
} from "@balancer-labs/v3-solidity-utils/contracts/helpers/TransientStorageHelpers.sol";

import { VaultStateBits } from "./lib/VaultStateLib.sol";
import { PoolConfigBits } from "./lib/PoolConfigLib.sol";

// solhint-disable max-states-count

/**
 * @notice Storage layout for the Vault.
 * @dev This contract has no code, but is inherited by all three Vault contracts. In order to ensure that *only* the
 * Vault contract's storage is actually used, calls to the extension contracts must be delegate calls made through the
 * main Vault.
 */
contract VaultStorage {
    using StorageSlotExtension for *;

    /***************************************************************************
                                     Constants
    ***************************************************************************/

    // Pools can have between two and eight tokens.
    uint256 internal constant _MIN_TOKENS = 2;
    // This maximum token count is also implicitly hard-coded in `PoolConfigLib` (through packing `tokenDecimalDiffs`).
    uint256 internal constant _MAX_TOKENS = 8;
    // Tokens with more than 18 decimals are not supported. Tokens must also implement `IERC20Metadata.decimals`.
    uint8 internal constant _MAX_TOKEN_DECIMALS = 18;

    // Maximum pause and buffer period durations.
    uint256 internal constant _MAX_PAUSE_WINDOW_DURATION = 365 days * 4;
    uint256 internal constant _MAX_BUFFER_PERIOD_DURATION = 180 days;

    // Minimum swap amount (applied to scaled18 values), enforced as a security measure to block potential
    // exploitation of rounding errors.
    // solhint-disable-next-line var-name-mixedcase
    uint256 internal immutable _MINIMUM_TRADE_AMOUNT;

    // Minimum given amount to wrap/unwrap (applied to native decimal values), to avoid rounding issues.
    // solhint-disable-next-line var-name-mixedcase
    uint256 internal immutable _MINIMUM_WRAP_AMOUNT;

    /***************************************************************************
                          Transient Storage Declarations
    ***************************************************************************/

    // NOTE: If you use a constant, then it is simply replaced everywhere when this constant is used
    // by what is written after =. If you use immutable, the value is first calculated and
    // then replaced everywhere. That means that if a constant has executable variables,
    // they will be executed every time the constant is used.

    // solhint-disable var-name-mixedcase
    bytes32 private immutable _IS_UNLOCKED_SLOT = _calculateVaultStorageSlot("isUnlocked");
    bytes32 private immutable _NON_ZERO_DELTA_COUNT_SLOT = _calculateVaultStorageSlot("nonZeroDeltaCount");
    bytes32 private immutable _TOKEN_DELTAS_SLOT = _calculateVaultStorageSlot("tokenDeltas");
    bytes32 private immutable _ADD_LIQUIDITY_CALLED_SLOT = _calculateVaultStorageSlot("addLiquidityCalled");
    bytes32 private immutable _SESSION_ID_SLOT = _calculateVaultStorageSlot("sessionId");
    // solhint-enable var-name-mixedcase

    /***************************************************************************
                                    Pool State
    ***************************************************************************/

    // Pool-specific configuration data (e.g., fees, pause window, configuration flags).
    mapping(address pool => PoolConfigBits poolConfig) internal _poolConfigBits;

    // Accounts assigned to specific roles; e.g., pauseManager, swapManager.
    mapping(address pool => PoolRoleAccounts roleAccounts) internal _poolRoleAccounts;

    // The hooks contracts associated with each pool.
    mapping(address pool => IHooks hooksContract) internal _hooksContracts;

    // The set of tokens associated with each pool.
    mapping(address pool => IERC20[] poolTokens) internal _poolTokens;

    // The token configuration of each Pool's tokens.
    mapping(address pool => mapping(IERC20 token => TokenInfo tokenInfo)) internal _poolTokenInfo;

    // Structure containing the current raw and "last live" scaled balances. Last live balances are used for
    // yield fee computation, and since these have rates applied, they are stored as scaled 18-decimal FP values.
    // Each value takes up half the storage slot (i.e., 128 bits).
    mapping(address pool => mapping(uint256 tokenIndex => bytes32 packedTokenBalance)) internal _poolTokenBalances;

    // Aggregate protocol swap/yield fees accumulated in the Vault for harvest.
    // Reusing PackedTokenBalance for the bytes32 values to save bytecode (despite differing semantics).
    // It's arbitrary which is which: we define raw = swap; derived = yield.
    mapping(address pool => mapping(IERC20 token => bytes32 packedFeeAmounts)) internal _aggregateFeeAmounts;

    /***************************************************************************
                                    Vault State
    ***************************************************************************/

    // The Pause Window and Buffer Period are timestamp-based: they should not be relied upon for sub-minute accuracy.
    uint32 internal immutable _vaultPauseWindowEndTime;
    uint32 internal immutable _vaultBufferPeriodEndTime;

    // Stored as a convenience, to avoid calculating it on every operation.
    uint32 internal immutable _vaultBufferPeriodDuration;

    // Bytes32 with pause flags for the Vault, buffers, and queries.
    VaultStateBits internal _vaultStateBits;

    /**
     * @dev Represents the total reserve of each ERC20 token. It should be always equal to `token.balanceOf(vault)`,
     * except during `unlock`.
     */
    mapping(IERC20 token => uint256 vaultBalance) internal _reservesOf;

    /// @dev Flag that prevents re-enabling queries.
    bool internal _queriesDisabledPermanently;

    /***************************************************************************
                                Contract References
    ***************************************************************************/

    // Upgradeable contract in charge of setting permissions.
    IAuthorizer internal _authorizer;

    // Contract that receives aggregate swap and yield fees.
    IProtocolFeeController internal _protocolFeeController;

    /***************************************************************************
                                  ERC4626 Buffers
    ***************************************************************************/

    // Any ERC4626 token can trade using a buffer, which is like a pool, but internal to the Vault.
    // The registry key is the wrapped token address, so there can only ever be one buffer per wrapped token.
    // This means they are permissionless, and have no registration function.
    //
    // Anyone can add liquidity to a buffer

    // A buffer will only ever have two tokens: wrapped and underlying. We pack the wrapped and underlying balances
    // into a single bytes32, interpreted with the `PackedTokenBalance` library.

    // ERC4626 token address -> PackedTokenBalance, which stores both the underlying and wrapped token balances.
    // Reusing PackedTokenBalance to save bytecode (despite differing semantics).
    // It's arbitrary which is which: we define raw = underlying token; derived = wrapped token.
    mapping(IERC4626 wrappedToken => bytes32 packedTokenBalance) internal _bufferTokenBalances;

    // The LP balances for buffers. LP balances are not tokenized (i.e., represented by ERC20 tokens like BPT), but
    // rather accounted for within the Vault.

    // Track the internal "BPT" shares of each buffer depositor.
    mapping(IERC4626 wrappedToken => mapping(address user => uint256 userShares)) internal _bufferLpShares;

    // Total LP shares.
    mapping(IERC4626 wrappedToken => uint256 totalShares) internal _bufferTotalShares;

    // Prevents a malicious ERC4626 from changing the asset after the buffer was initialized.
    mapping(IERC4626 wrappedToken => address underlyingToken) internal _bufferAssets;

    /***************************************************************************
                             Transient Storage Access
    ***************************************************************************/

    function _isUnlocked() internal view returns (StorageSlotExtension.BooleanSlotType slot) {
        return _IS_UNLOCKED_SLOT.asBoolean();
    }

    function _nonZeroDeltaCount() internal view returns (StorageSlotExtension.Uint256SlotType slot) {
        return _NON_ZERO_DELTA_COUNT_SLOT.asUint256();
    }

    function _tokenDeltas() internal view returns (TokenDeltaMappingSlotType slot) {
        return TokenDeltaMappingSlotType.wrap(_TOKEN_DELTAS_SLOT);
    }

    function _addLiquidityCalled() internal view returns (UintToAddressToBooleanMappingSlot slot) {
        return UintToAddressToBooleanMappingSlot.wrap(_ADD_LIQUIDITY_CALLED_SLOT);
    }

    function _sessionIdSlot() internal view returns (StorageSlotExtension.Uint256SlotType slot) {
        return _SESSION_ID_SLOT.asUint256();
    }

    function _calculateVaultStorageSlot(string memory key) private pure returns (bytes32) {
        return TransientStorageHelpers.calculateSlot(type(VaultStorage).name, key);
    }
}
