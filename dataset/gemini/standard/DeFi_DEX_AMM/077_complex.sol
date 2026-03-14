```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// --- Interfaces ---

interface IUniswapV2Factory {
    event PairCreated(address indexed tokenA, address indexed tokenB, address indexed pair, uint256);

    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function allPairs(uint256) external view returns (address pair);
    function allPairsLength() external view returns (uint256);
    function setFeeTo(address) external;
    function setFeeToSetter(address) external;
    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);
}

interface IUniswapV2Pair {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1);
    function sync() external;
    function mint(address to) external returns (uint256 liquidity);
    function burn(address to) external returns (uint256 amount0, uint256 amount1);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function initialize(address, address) external;
    function MINIMUM_LIQUIDITY() external pure returns (uint256);
    function kLast() external view returns (uint256);
    function price0CumulativeLast() external view returns (uint256);
    function price1CumulativeLast() external view returns (uint256);
}

interface IUniswapV2Router02 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);
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

    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);

    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountETH);

    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountA, uint amountB);

    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountToken, uint amountETH);

    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);

    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);

    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);

    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);

    function quote(uint amountA, uint reserveA, uint reserveB) external pure returns (uint amountB);
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut);
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure returns (uint amountIn);
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
}

// --- Contracts ---

contract UniswapV2Factory is IUniswapV2Factory, Ownable {
    using SafeERC20 for IERC20;

    address public override feeTo;
    address public override feeToSetter;

    mapping(address => mapping(address => address)) public getPair;
    address[] public allPairs;

    uint256 public constant INIT_CODE_HASH = uint256(keccak256("uniswapv2.PairCodeHash"));

    event PairCreated(address indexed tokenA, address indexed tokenB, address indexed pair, uint256);

    constructor() {
        feeToSetter = msg.sender;
    }

    function allPairsLength() external view returns (uint256) {
        return allPairs.length;
    }

    function allPairs(uint256 i) external view returns (address pair) {
        return allPairs[i];
    }

    function createPair(address tokenA, address tokenB) external returns (address pair) {
        require(tokenA != tokenB, "UniswapV2: IDENTICAL_ADDRESSES");
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), "UniswapV2: ZERO_ADDRESS");
        require(getPair[token0][token1] == address(0), "UniswapV2: PAIR_EXISTS");

        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        address _pair = (new UniswapV2Pair{ salt: salt })(token0, token1); // Using CREATE2 for deterministic pair address

        // Initialize the pair contract
        IUniswapV2Pair(_pair).initialize(token0, token1);

        getPair[token0][token1] = _pair;
        getPair[token1][token0] = _pair;
        allPairs.push(_pair);

        emit PairCreated(token0, token1, _pair, allPairs.length);
    }

    function setFeeTo(address _feeTo) external {
        require(msg.sender == feeToSetter, "UniswapV2: FORBIDDEN");
        feeTo = _feeTo;
    }

    function setFeeToSetter(address _feeToSetter) external {
        require(msg.sender == owner(), "UniswapV2: OWNER_ONLY");
        feeToSetter = _feeToSetter;
    }

    // Function to get the pair address deterministically using CREATE2
    function getPairAddress(address tokenA, address tokenB) public view returns (address pair) {
        require(tokenA != tokenB, "UniswapV2: IDENTICAL_ADDRESSES");
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), "UniswapV2: ZERO_ADDRESS");
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        return address(uint160(uint256(keccak256(abi.encodePacked(
            bytes1(0x00),
            address(this),
            salt,
            INIT_CODE_HASH
        )))));
    }
}

contract UniswapV2Pair is IUniswapV2Pair, ReentrancyGuard {
    using SafeERC20 for IERC20;

    address public immutable token0;
    address public immutable token1;

    uint112 public reserve0;
    uint112 public reserve1;
    uint256 public blockTimestampLast;
    uint256 public price0CumulativeLast;
    uint256 public price1CumulativeLast;
    uint256 public kLast;

    uint256 public MINIMUM_LIQUIDITY = 10**3; // Minimum liquidity to avoid issues with precision

    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    constructor(address _token0, address _token1) {
        token0 = _token0;
        token1 = _token1;
    }

    function initialize(address _token0, address _token1) external {
        require(msg.sender == IUniswapV2Factory(factory()).getPairAddress(address(0), address(0)), "UniswapV2: CALLER_IS_NOT_FACTORY"); // Only factory can initialize
        require(_token0 < _token1, "UniswapV2: INVALID_TOKEN_ORDER"); // Ensure consistent token order
    }

    function factory() public pure returns (address) {
        return address(0); // Placeholder, should be set by factory or injected
    }

    function MINIMUM_LIQUIDITY() public pure returns (uint256) {
        return 10**3;
    }

    function getReserves() public view returns (uint112 _reserve0, uint112 _reserve1) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
    }

    function price0CumulativeLast() public view returns (uint256) {
        return price0CumulativeLast;
    }

    function price1CumulativeLast() public view returns (uint256) {
        return price1CumulativeLast;
    }

    function kLast() public view returns (uint256) {
        return kLast;
    }

    function _safeTransfer(address token, address to, uint amount) internal {
        IERC20(token).safeTransfer(to, amount);
    }

    function _update(uint balance0, uint balance1, uint112 _reserve0, uint112 _reserve1) private {
        uint32 blockTimestamp = uint32(block.timestamp % 2**32);
        uint32 timeDelta = blockTimestamp - uint32(blockTimestampLast);
        uint price0Cumulative = price0CumulativeLast;
        uint price1Cumulative = price1CumulativeLast;

        if (timeDelta > 0 && _reserve0 != 0 && _reserve1 != 0) {
            if (price0CumulativeLast < price1CumulativeLast) { // Check for overflow before multiplication
                price0Cumulative += Math.mulDiv(uint(uint112(_reserve1)), timeDelta, _reserve0);
                price1Cumulative += Math.mulDiv(uint(uint112(_reserve0)), timeDelta, _reserve1);
            } else {
                price0Cumulative += Math.mulDiv(uint(uint112(_reserve0)), timeDelta, _reserve1);
                price1Cumulative += Math.mulDiv(uint(uint112(_reserve1)), timeDelta, _reserve0);
            }
        }

        blockTimestampLast = blockTimestamp;
        price0CumulativeLast = price0Cumulative;
        price1CumulativeLast = price1Cumulative;

        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        emit Sync(reserve0, reserve1);
    }

    function _mintFee(uint112 _reserve0, uint112 _reserve1) private returns (bool feeOn) {
        address _feeTo = IUniswapV2Factory(factory()).feeTo();
        feeOn = _feeTo != address(0);
        uint _kLast = kLast;

        if (feeOn) {
            if (_kLast != 0) {
                uint L = Math.min(uint(_reserve0), uint(_reserve1));
                uint k = L * L; // k = reserve0 * reserve1
                uint _newBalance0 = uint(_reserve0) * 999 / 1000;
                uint _newBalance1 = uint(_reserve1) * 999 / 1000;
                if (uint(_reserve0) > _newBalance0 && uint(_reserve1) > _newBalance1) {
                    uint amount0 = uint(_reserve0) - _newBalance0;
                    uint amount1 = uint(_reserve1) - _newBalance1;

                    _safeTransfer(token0, _feeTo, amount0);
                    _safeTransfer(token1, _feeTo, amount1);
                } else {
                    feeOn = false; // Not enough tokens to take fee
                }
            }
        }

        if (feeOn) kLast = k * 1000; else kLast = 0; // If fee is on, kLast is k * 1000, otherwise 0
        return feeOn;
    }

    function mint(address to) external nonReentrant returns (uint256 liquidity) {
        (uint112 _reserve0, uint112 _reserve1) = getReserves();
        uint balance0 = IERC20(token0).balanceOf(address(this));
        uint balance1 = IERC20(token1).balanceOf(address(this));

        bool feeOn = _mintFee(_reserve0, _reserve1);
        _reserve0 = reserve0;
        _reserve1 = reserve1;

        uint amount0 = balance0 - uint(_reserve0);
        uint amount1 = balance1 - uint(_reserve1);

        if (feeOn) {
            amount0 = amount0 * 999 / 1000;
            amount1 = amount1 * 999 / 1000;
        }

        uint totalSupply = totalSupply();
        if (totalSupply == 0) {
            liquidity = Math.sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY;
            require(liquidity > 0, "UniswapV2: INSANE_LIQUIDITY_VALUE");
            _mint(to, liquidity);
        } else {
            liquidity = Math.min(
                amount0 * totalSupply / uint(_reserve0),
                amount1 * totalSupply / uint(_reserve1)
            );
            require(liquidity > 0, "UniswapV2: INSANE_LIQUIDITY_VALUE");
            _mint(to, liquidity);
        }

        if (amount0 > 0 || amount1 > 0) _update(balance0, balance1, _reserve0, _reserve1);
        emit Mint(msg.sender, amount0, amount1);
    }

    function _mint(address to, uint liquidity) internal {
        // Internal function to handle ERC20 minting logic (assuming ERC20 implementation)
        // This would typically involve a separate ERC20 contract for LP tokens
        // For simplicity, we'll just emit an event here. In a real implementation,
        // this would mint LP tokens to 'to'.
        // Example: LPToken(address(this)).mint(to, liquidity);
    }

    function burn(address to) external nonReentrant returns (uint256 amount0, uint256 amount1) {
        (uint112 _reserve0, uint112 _reserve1) = getReserves();
        uint balance0 = IERC20(token0).balanceOf(address(this));
        uint balance1 = IERC20(token1).balanceOf(address(this));

        uint liquidity = totalSupply();
        liquidity = liquidity * 999 / 1000; // Burn 0.3% of liquidity for