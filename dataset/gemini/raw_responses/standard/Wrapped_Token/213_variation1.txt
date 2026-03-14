```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title WrappedRebaser
 * @dev A contract that wraps a rebasing ERC20 token and presents it as a fixed-balance ERC20 token.
 * The wrapped token's balance is always a direct reflection of the underlying rebasing token's balance
 * at the time of the last rebase event.
 */
contract WrappedRebaser is ERC20, Ownable {
    address public immutable underlyingTokenAddress;
    uint256 public constant DECIMALS = 18; // The fixed decimals for the wrapped token

    // State variable to store the amount of underlying tokens that corresponds to 1 unit of wrapped token
    // This is effectively the "normalization factor" or "exchange rate"
    uint256 public normalizedUnderlyingPerWrapped = 10**DECIMALS;

    event Rebase(uint256 newTotalSupply);
    event UnderlyingBalanceUpdated(address indexed user, uint256 newBalance);

    /**
     * @dev Constructor for the WrappedRebaser contract.
     * @param _underlyingTokenAddress The address of the rebasing ERC20 token to wrap.
     * @param _initialWrappedName The name of the wrapped token.
     * @param _initialWrappedSymbol The symbol of the wrapped token.
     */
    constructor(address _underlyingTokenAddress, string memory _initialWrappedName, string memory _initialWrappedSymbol)
        ERC20(_initialWrappedName, _initialWrappedSymbol)
    {
        require(_underlyingTokenAddress != address(0), "WrappedRebaser: Invalid underlying token address");
        underlyingTokenAddress = _underlyingTokenAddress;
    }

    /**
     * @dev Internal function to get the underlying token contract.
     */
    function _getUnderlyingToken() internal view returns (ERC20) {
        return ERC20(underlyingTokenAddress);
    }

    /**
     * @dev Internal function to get the current balance of the underlying token for a given address.
     * This assumes the underlying token has a `balanceOf` function.
     * @param _account The address to check the balance for.
     * @return The balance of the underlying token.
     */
    function _getUnderlyingBalance(address _account) internal view returns (uint256) {
        return _getUnderlyingToken().balanceOf(_account);
    }

    /**
     * @dev Normalizes the balance of the underlying token to the wrapped token's fixed decimals.
     * This function is crucial for maintaining the fixed-balance ERC20 representation.
     * @param _underlyingAmount The amount of underlying tokens.
     * @return The normalized amount in wrapped token's decimals.
     */
    function _normalizeToWrapped(uint256 _underlyingAmount) internal view returns (uint256) {
        // This assumes underlying token might have different decimals.
        // If underlying token has same decimals as DECIMALS, this simplifies to _underlyingAmount.
        // For simplicity, let's assume underlying token has its own decimals and we need to adjust.
        // If underlying token has more decimals, we multiply. If less, we divide.
        // A more robust implementation would read underlying decimals dynamically.
        // For this example, let's assume underlying token has 18 decimals.
        // If the underlying token has a different number of decimals than our wrapped token,
        // we need to adjust. For simplicity, let's assume underlying token has 18 decimals.
        // If the underlying token's decimals are different, you'd need to read them dynamically.

        // Example: If underlying has 27 decimals and wrapped has 18, we divide by 10^9.
        // If underlying has 18 decimals and wrapped has 18, no adjustment needed.
        // If underlying has 6 decimals and wrapped has 18, we multiply by 10^12.

        // For this example, let's assume underlying token has 18 decimals, same as DECIMALS.
        // If your underlying token has different decimals, you'll need to implement
        // logic to read its decimals and adjust accordingly.
        uint256 underlyingDecimals = 18; // Replace with dynamic reading if needed

        if (underlyingDecimals > DECIMALS) {
            return _underlyingAmount / (10**(underlyingDecimals - DECIMALS));
        } else if (underlyingDecimals < DECIMALS) {
            return _underlyingAmount * (10**(DECIMALS - underlyingDecimals));
        } else {
            return _underlyingAmount;
        }
    }

    /**
     * @dev Converts an amount from wrapped token's fixed balance to the underlying token's balance.
     * @param _wrappedAmount The amount in the wrapped token's decimals.
     * @return The corresponding amount in the underlying token's decimals.
     */
    function _convertToUnderlying(uint256 _wrappedAmount) internal view returns (uint256) {
        // Similar to _normalizeToWrapped, adjust based on underlying token's decimals.
        // Assuming underlying token has 18 decimals.
        uint256 underlyingDecimals = 18; // Replace with dynamic reading if needed

        if (underlyingDecimals > DECIMALS) {
            return _wrappedAmount * (10**(underlyingDecimals - DECIMALS));
        } else if (underlyingDecimals < DECIMALS) {
            return _wrappedAmount / (10**(DECIMALS - underlyingDecimals));
        } else {
            return _wrappedAmount;
        }
    }

    /**
     * @dev Mints wrapped tokens to a user's account.
     * This is typically done when a user deposits underlying tokens into the wrapper.
     * The amount minted is based on the current normalized balance.
     * @param _to The address to mint wrapped tokens to.
     * @param _underlyingAmount The amount of underlying tokens being deposited.
     */
    function mintWrapped(address _to, uint256 _underlyingAmount) external onlyOwner {
        require(_to != address(0), "WrappedRebaser: Invalid recipient address");
        require(_underlyingAmount > 0, "WrappedRebaser: Amount must be greater than zero");

        // Transfer underlying tokens from the owner (or a designated address) to the wrapper contract
        // This assumes the owner has the underlying tokens to deposit initially.
        // A more complex system might involve a user depositing directly.
        bool success = _getUnderlyingToken().transferFrom(msg.sender, address(this), _underlyingAmount);
        require(success, "WrappedRebaser: Failed to transfer underlying tokens");

        // Calculate the amount of wrapped tokens to mint based on the normalized balance.
        // We are effectively taking the underlying amount and representing it in our fixed-balance system.
        uint256 wrappedAmountToMint = _normalizeToWrapped(_underlyingAmount);

        _mint(_to, wrappedAmountToMint);

        emit UnderlyingBalanceUpdated(_to, _getUnderlyingBalance(_to));
    }

    /**
     * @dev Burns wrapped tokens from a user's account and returns underlying tokens.
     * This is typically done when a user withdraws their underlying assets.
     * The amount of underlying tokens returned is based on the current normalized balance.
     * @param _from The address to burn wrapped tokens from.
     * @param _wrappedAmount The amount of wrapped tokens to burn.
     */
    function burnWrapped(address _from, uint256 _wrappedAmount) external onlyOwner {
        require(_from != address(0), "WrappedRebaser: Invalid sender address");
        require(_wrappedAmount > 0, "WrappedRebaser: Amount must be greater than zero");

        // Burn the wrapped tokens from the sender
        _burn(_from, _wrappedAmount);

        // Calculate the amount of underlying tokens to return
        uint256 underlyingAmountToReturn = _convertToUnderlying(_wrappedAmount);

        // Transfer underlying tokens back to the user
        bool success = _getUnderlyingToken().transfer(_from, underlyingAmountToReturn);
        require(success, "WrappedRebaser: Failed to transfer underlying tokens");

        emit UnderlyingBalanceUpdated(_from, _getUnderlyingBalance(_from));
    }

    /**
     * @dev This function is called when the underlying rebasing token rebases.
     * The owner (or a designated rebalancer) should call this function to update
     * the internal state and potentially adjust the `normalizedUnderlyingPerWrapped`
     * if the rebasing token's total supply changes significantly.
     *
     * IMPORTANT: This function is a placeholder. A real-world implementation
     * would need a mechanism to detect rebases or be triggered by an oracle/event.
     * The logic for updating `normalizedUnderlyingPerWrapped` is complex and
     * depends on the specific rebasing token's mechanics.
     *
     * For this example, we'll assume a simplified rebase where the total supply
     * of the underlying token changes, and we need to update our normalization factor.
     * A common approach is to re-calculate the exchange rate based on the total
     * supply of the underlying token and the total supply of the wrapped token.
     *
     * @param _newUnderlyingTotalSupply The new total supply of the underlying rebasing token.
     *                                 This would typically be obtained from the rebasing token's contract.
     */
    function rebase(uint256 _newUnderlyingTotalSupply) external onlyOwner {
        // This function should be called whenever the underlying token rebases.
        // The owner is responsible for monitoring rebases and calling this.

        // Get the current total supply of the underlying token (as it was before the rebase, for reference)
        // This is tricky as the rebase event might have already happened on the underlying token.
        // A more robust approach would be to read the underlying token's total supply *after* its rebase.
        // For this example, we'll assume _newUnderlyingTotalSupply is the supply *after* the rebase.

        uint256 currentWrappedTotalSupply = totalSupply();
        uint256 currentUnderlyingTotalSupply = _getUnderlyingTotalSupply(); // Need to implement this helper

        if (currentWrappedTotalSupply == 0) {
            // If no wrapped tokens exist, we can't calculate a ratio.
            // Initialize the normalization factor based on the new underlying total supply.
            // This is a bit arbitrary and might need refinement.
            // A safe default might be to set it to the initial minted amount if any.
            // For simplicity, let's assume if no wrapped tokens, no change to normalization.
            return;
        }

        if (_newUnderlyingTotalSupply == 0) {
            // Avoid division by zero.
            return;
        }

        // Calculate the new normalization factor:
        // new_normalizedUnderlyingPerWrapped = (_newUnderlyingTotalSupply * 10^DECIMALS) / currentWrappedTotalSupply
        // This aims to maintain that the total underlying assets represented by the wrapped token
        // match the total underlying supply.
        uint256 newNormalizedUnderlyingPerWrapped = (_newUnderlyingTotalSupply * (10**DECIMALS)) / currentWrappedTotalSupply;

        // Update the normalization factor
        normalizedUnderlyingPerWrapped = newNormalizedUnderlyingPerWrapped;

        emit Rebase(currentWrappedTotalSupply); // Emit an event indicating a rebase event occurred
    }

    /**
     * @dev Helper function to get the total supply of the underlying token.
     * This function needs to be implemented based on how the underlying rebasing token
     * exposes its total supply. Some rebasing tokens have a `totalSupply` function,
     * others might require a more complex calculation or an oracle.
     *
     * IMPORTANT: This is a placeholder. You MUST implement this correctly
     * based on the actual rebasing token you are wrapping.
     *
     * @return The total supply of the underlying rebasing token.
     */
    function _getUnderlyingTotalSupply() internal view returns (uint256) {
        // Replace this with the actual way to get the underlying token's total supply.
        // Example: If the underlying token is an ERC20 with a totalSupply() function:
        // return _getUnderlyingToken().totalSupply();
        //
        // If it's a rebasing token like AMPL or OHM, you might need to call a specific function
        // to get the *current* total supply after its rebase.
        // For demonstration, let's assume a standard ERC20 totalSupply() function.
        return _getUnderlyingToken().totalSupply();
    }

    /**
     * @dev Returns the current balance of the underlying token for a given account.
     * This is a public view function for users to check their underlying balance.
     * @param _account The address to check the balance for.
     * @return The normalized balance of the underlying token.
     */
    function getUnderlyingBalance(address _account) external view returns (uint256) {
        return _getUnderlyingBalance(_account);
    }

    /**
     * @dev Returns the current total supply of the underlying token.
     * This is a public view function for users to check the underlying total supply.
     * @return The total supply of the underlying token.
     */
    function getUnderlyingTotalSupply() external view returns (uint256) {
        return _getUnderlyingTotalSupply();
    }

    /**
     * @dev Returns the current exchange rate between wrapped tokens and underlying tokens.
     * This is useful for users to understand the current conversion factor.
     * @return The amount of underlying tokens that 1 wrapped token represents.
     */
    function getExchangeRate() external view returns (uint256) {
        // This represents how many units of underlying token are represented by 1 unit of wrapped token.
        // It's derived from normalizedUnderlyingPerWrapped.
        // If normalizedUnderlyingPerWrapped = 10^18, it means 1 wrapped token = 1 underlying token (assuming 18 decimals).
        // If normalizedUnderlyingPerWrapped = 10^27, it means 1 wrapped token = 10^9 underlying tokens.
        return normalizedUnderlyingPerWrapped;
    }

    // --- Standard ERC20 Functions ---
    // These functions will operate on the fixed balance of the wrapped token.
    // The `mint` and `burn` functions are handled by `mintWrapped` and `burnWrapped`
    // which interact with the underlying rebasing token.

    /**
     * @dev See {ERC20-_beforeTokenTransfer}.
     * This hook is called before any token transfer (mint, burn, transfer, transferFrom).
     * It ensures that the underlying balances are updated correctly after a rebase event.
     *
     * IMPORTANT: The rebase event handling in this contract is simplified.
     * A robust implementation would require a reliable way to detect underlying rebases
     * and trigger the `rebase` function in this contract.
     *
     * This _beforeTokenTransfer hook is primarily for ensuring internal consistency
     * if the `rebase` function has been called appropriately.
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override {
        super._beforeTokenTransfer(from, to, amount);

        // When tokens are transferred, the underlying balance of the sender and receiver
        // might need to be adjusted if a rebase has occurred since their last interaction.
        // This is a complex part. A simpler approach is to rely on the user calling
        // `mintWrapped` and `burnWrapped` which explicitly handle the underlying token interaction.

        // For a true fixed-balance ERC20 wrapper, the `transfer` function of the wrapped token
        // should NOT directly interact with the underlying token. The interaction happens
        // only during minting/burning of the wrapper.

        // If a rebase has happened, and `normalizedUnderlyingPerWrapped` has changed,
        // the actual underlying value of a user's wrapped tokens changes.
        // However, the ERC20 `transfer` function operates on the *fixed* balance.
        // The user's underlying balance is updated when they call `mintWrapped` or `burnWrapped`.
        // The `rebase` function is responsible for keeping `normalizedUnderlyingPerWrapped` up-to-date.

        // If you want users to be able to "claim" their updated underlying balance
        // after a rebase, you would need a separate function for that, or integrate
        // it into `mintWrapped`/`burnWrapped`.

        // For this implementation, the `rebase` function is the key to updating the
        // perceived value. The `_beforeTokenTransfer` hook is less critical for the
        // core rebasing logic itself, but good for general ERC20 contract hygiene.

        // We can emit events here to indicate underlying balance changes if desired,
        // but it's more direct to do it in mintWrapped/burnWrapped.
        if (from != address(0) && _getUnderlyingBalance(from) > 0) {
             emit UnderlyingBalanceUpdated(from, _getUnderlyingBalance(from));
        }
        if (to != address(0) && _getUnderlyingBalance(to) > 0) {
             emit UnderlyingBalanceUpdated(to, _