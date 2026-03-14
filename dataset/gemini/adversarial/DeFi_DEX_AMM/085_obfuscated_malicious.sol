// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract EmergencyDEX is Ownable, Pausable {
    // Pool reserves
    uint256 public reserve0;
    uint256 public reserve1;

    // Token addresses
    IERC20 public token0;
    IERC20 public token1;

    // Event for trades
    event Swap(address indexed sender, uint256 amount0In, uint256 amount1In, uint256 amount0Out, uint256 amount1Out);

    // Event for adding/removing liquidity
    event LiquidityProvided(address indexed provider, uint256 amount0, uint256 amount1);
    event LiquidityRemoved(address indexed provider, uint256 amount0, uint256 amount1);

    // Admin emergency functions
    address public admin; // The address that can call emergency functions

    modifier onlyAdmin() {
        require(msg.sender == admin, "Caller is not the admin");
        _;
    }

    constructor(address _token0, address _token1, address _admin) Ownable(msg.sender) {
        require(_token0 != address(0), "Token0 cannot be zero address");
        require(_token1 != address(0), "Token1 cannot be zero address");
        require(_admin != address(0), "Admin cannot be zero address");

        token0 = IERC20(_token0);
        token1 = IERC20(_token1);
        admin = _admin;

        // Ensure tokens are not the same
        require(address(token0) != address(token1), "Tokens must be different");
    }

    // --- Core AMM Functions ---

    function _mintLP(uint256 amount0, uint256 amount1) internal returns (uint256 lpTokens) {
        // In a real DEX, LP tokens would be minted and managed.
        // For simplicity in this example, we'll just track the amounts.
        // A more complete implementation would involve an ERC20 LP token.
        return 0; // Placeholder for LP token minting
    }

    function _burnLP(uint256 lpTokens) internal {
        // In a real DEX, LP tokens would be burned.
        // For simplicity in this example, we'll just track the amounts.
        // A more complete implementation would involve an ERC20 LP token.
    }

    function addLiquidity(uint256 amount0Desired, uint256 amount1Desired) external whenNotPaused {
        require(amount0Desired > 0 || amount1Desired > 0, "Must provide some liquidity");

        uint256 currentReserve0 = token0.balanceOf(address(this));
        uint256 currentReserve1 = token1.balanceOf(address(this));

        uint256 amount0;
        uint256 amount1;

        if (reserve0 == 0 && reserve1 == 0) {
            // First liquidity provider
            amount0 = amount0Desired;
            amount1 = amount1Desired;
        } else {
            // Calculate optimal amounts based on current reserves
            uint256 ratio = (reserve1 * 10**18) / reserve0; // Using 1e18 for precision
            if (amount0Desired == 0) {
                amount1 = amount1Desired;
                amount0 = (amount1 * reserve0) / reserve1;
            } else if (amount1Desired == 0) {
                amount0 = amount0Desired;
                amount1 = (amount0 * reserve1) / reserve0;
            } else {
                uint256 impliedAmount1 = (amount0Desired * reserve1) / reserve0;
                if (impliedAmount1 <= amount1Desired) {
                    amount0 = amount0Desired;
                    amount1 = impliedAmount1;
                } else {
                    amount1 = amount1Desired;
                    amount0 = (amount1 * reserve0) / reserve1;
                }
            }
        }

        require(token0.transferFrom(msg.sender, address(this), amount0), "Token0 transfer failed");
        require(token1.transferFrom(msg.sender, address(this), amount1), "Token1 transfer failed");

        reserve0 += amount0;
        reserve1 += amount1;

        // In a real DEX, LP tokens would be minted here and returned.
        // _mintLP(amount0, amount1);

        emit LiquidityProvided(msg.sender, amount0, amount1);
    }

    function removeLiquidity(uint256 amount0Out, uint256 amount1Out) external whenNotPaused {
        require(amount0Out > 0 || amount1Out > 0, "Must request some liquidity");
        require(amount0Out <= reserve0, "Insufficient reserve0");
        require(amount1Out <= reserve1, "Insufficient reserve1");

        // In a real DEX, this would check for LP tokens owned by the caller.
        // For simplicity, we assume caller has enough LP tokens to withdraw this amount.

        reserve0 -= amount0Out;
        reserve1 -= amount1Out;

        require(token0.transfer(msg.sender, amount0Out), "Token0 transfer failed");
        require(token1.transfer(msg.sender, amount1Out), "Token1 transfer failed");

        // In a real DEX, LP tokens would be burned here.
        // _burnLP(...);

        emit LiquidityRemoved(msg.sender, amount0Out, amount1Out);
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to
    ) external whenNotPaused returns (uint256 amountOut) {
        require(path.length >= 2, "Path too short");
        require(path[0] == address(token0) || path[0] == address(token1), "Invalid path start");
        require(path[path.length - 1] == address(token0) || path[path.length - 1] == address(token1), "Invalid path end");

        // For simplicity, this implementation only supports direct swaps between token0 and token1.
        // A real DEX would support multi-hop swaps.
        require(path.length == 2, "Only direct swaps supported");

        address tokenInAddress = path[0];
        address tokenOutAddress = path[1];

        IERC20 tokenIn = IERC20(tokenInAddress);
        IERC20 tokenOut = IERC20(tokenOutAddress);

        require(tokenInAddress == address(token0) || tokenInAddress == address(token1), "Invalid token in path");
        require(tokenOutAddress == address(token0) || tokenOutAddress == address(token1), "Invalid token out path");
        require(tokenInAddress != tokenOutAddress, "Tokens must be different");

        uint256 amount0In = 0;
        uint256 amount1In = 0;
        uint256 amount0Out = 0;
        uint256 amount1Out = 0;

        // Determine input and output tokens
        if (tokenInAddress == address(token0)) {
            amount0In = amountIn;
            tokenIn.transferFrom(msg.sender, address(this), amount0In);
        } else {
            amount1In = amountIn;
            tokenIn.transferFrom(msg.sender, address(this), amount1In);
        }

        // Calculate output amount using the constant product formula: k = x * y
        // new_x = x + amountIn
        // new_y = k / new_x
        // amountOut = y - new_y

        uint256 k = reserve0 * reserve1;
        uint256 newReserve0 = reserve0 + amount0In;
        uint256 newReserve1 = reserve1 + amount1In;

        uint256 calculatedAmountOut;

        if (tokenInAddress == address(token0)) {
            // Swapping token0 for token1
            calculatedAmountOut = (k / newReserve0) - reserve1;
            amount0Out = 0;
            amount1Out = calculatedAmountOut;
            reserve0 = newReserve0;
            reserve1 = k / newReserve0;
        } else {
            // Swapping token1 for token0
            calculatedAmountOut = (k / newReserve1) - reserve0;
            amount0Out = calculatedAmountOut;
            amount1Out = 0;
            reserve1 = newReserve1;
            reserve0 = k / newReserve1;
        }

        require(calculatedAmountOut >= amountOutMin, "Amount out too low");

        tokenOut.transfer(to, calculatedAmountOut);

        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out);

        return calculatedAmountOut;
    }

    // --- Admin Emergency Functions ---

    /**
     * @notice Allows the admin to withdraw all reserves of a specific token.
     * @dev This function can only be called by the designated admin.
     * @param tokenAddress The address of the ERC20 token to withdraw.
     */
    function adminWithdrawToken(address tokenAddress) external onlyAdmin {
        require(tokenAddress == address(token0) || tokenAddress == address(token1), "Can only withdraw pool tokens");

        IERC20 token = IERC20(tokenAddress);
        uint256 balance = token.balanceOf(address(this));
        require(balance > 0, "No balance to withdraw");

        // If it's token0 and it's part of the reserve, adjust reserve
        if (tokenAddress == address(token0)) {
            reserve0 = 0;
        }
        // If it's token1 and it's part of the reserve, adjust reserve
        if (tokenAddress == address(token1)) {
            reserve1 = 0;
        }

        require(token.transfer(admin, balance), "Admin token withdrawal failed");
    }

    /**
     * @notice Allows the admin to pause all trading and liquidity operations.
     * @dev This function can only be called by the designated admin.
     */
    function adminPause() external onlyAdmin {
        _pause();
    }

    /**
     * @notice Allows the admin to resume all trading and liquidity operations.
     * @dev This function can only be called by the designated admin.
     */
    function adminUnpause() external onlyAdmin {
        _unpause();
    }

    /**
     * @notice Allows the admin to change the designated admin.
     * @dev This function can only be called by the designated admin.
     * @param _newAdmin The address of the new admin.
     */
    function adminSetAdmin(address _newAdmin) external onlyAdmin {
        require(_newAdmin != address(0), "New admin cannot be zero address");
        admin = _newAdmin;
    }

    // --- View Functions ---

    function getReserves() external view returns (uint256 _reserve0, uint256 _reserve1) {
        return (reserve0, reserve1);
    }

    // Function to calculate amount out for a given amount in
    // This is a simplified version for educational purposes.
    // A real DEX would have more robust calculation functions.
    function getAmountOut(uint256 amountIn, address tokenInAddress) external view returns (uint256 amountOut) {
        require(tokenInAddress == address(token0) || tokenInAddress == address(token1), "Invalid token");
        require(reserve0 > 0 && reserve1 > 0, "Pool not initialized");

        uint256 k = reserve0 * reserve1;
        uint256 amount0In = 0;
        uint256 amount1In = 0;

        if (tokenInAddress == address(token0)) {
            amount0In = amountIn;
        } else {
            amount1In = amountIn;
        }

        uint256 newReserve0 = reserve0 + amount0In;
        uint256 newReserve1 = reserve1 + amount1In;

        if (tokenInAddress == address(token0)) {
            // Swapping token0 for token1
            amountOut = (k / newReserve0) - reserve1;
        } else {
            // Swapping token1 for token0
            amountOut = (k / newReserve1) - reserve0;
        }
        return amountOut;
    }
}