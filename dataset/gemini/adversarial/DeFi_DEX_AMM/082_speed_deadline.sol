// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract SimpleDEX is Ownable {
    mapping(address => mapping(address => uint256)) public reserves;
    mapping(address => mapping(address => address)) public tokenPairs; // tokenA => tokenB => pairAddress

    event TokenPairCreated(address indexed tokenA, address indexed tokenB, address indexed pairAddress);
    event LiquidityAdded(address indexed tokenA, address indexed tokenB, uint256 amountA, uint256 amountB);
    event LiquidityRemoved(address indexed tokenA, address indexed tokenB, uint256 amountA, uint256 amountB);
    event SwapExecuted(address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut);

    function createTokenPair(address tokenA, address tokenB) public onlyOwner {
        require(tokenA != tokenB, "Cannot pair a token with itself.");
        require(tokenA != address(0) && tokenB != address(0), "Invalid token address.");

        address pairAddress = address(new Pair(tokenA, tokenB, address(this)));

        tokenPairs[tokenA][tokenB] = pairAddress;
        tokenPairs[tokenB][tokenA] = pairAddress;

        emit TokenPairCreated(tokenA, tokenB, pairAddress);
    }

    function getPairAddress(address tokenA, address tokenB) public view returns (address) {
        require(tokenA != tokenB, "Cannot pair a token with itself.");
        require(tokenA != address(0) && tokenB != address(0), "Invalid token address.");
        return tokenPairs[tokenA][tokenB];
    }

    function addLiquidity(address tokenA, address tokenB, uint256 amountA, uint256 amountB) public {
        address pairAddress = getPairAddress(tokenA, tokenB);
        require(pairAddress != address(0), "Token pair does not exist.");

        IERC20(tokenA).transferFrom(msg.sender, pairAddress, amountA);
        IERC20(tokenB).transferFrom(msg.sender, pairAddress, amountB);

        // Update reserves (this is handled by the Pair contract)
        // Pair contract will emit LiquidityAdded event
    }

    function removeLiquidity(address tokenA, address tokenB, uint256 amountA, uint256 amountB) public {
        address pairAddress = getPairAddress(tokenA, tokenB);
        require(pairAddress != address(0), "Token pair does not exist.");

        IERC20(tokenA).transfer(pairAddress, amountA); // Transfer to the pair contract to burn LP tokens
        IERC20(tokenB).transfer(pairAddress, amountB); // Transfer to the pair contract to burn LP tokens

        // The Pair contract will handle burning LP tokens and transferring back underlying assets
        // Pair contract will emit LiquidityRemoved event
    }

    function swap(address tokenIn, address tokenOut, uint256 amountIn) public {
        address pairAddress = getPairAddress(tokenIn, tokenOut);
        require(pairAddress != address(0), "Token pair does not exist.");

        IERC20(tokenIn).transferFrom(msg.sender, pairAddress, amountIn);

        // The Pair contract will handle the swap logic and emit SwapExecuted event
    }

    // Fallback function to receive Ether if needed, though this is primarily for ERC20 tokens
    receive() external payable {}
}

contract Pair is Ownable {
    address public immutable tokenA;
    address public immutable tokenB;
    address public immutable dex;
    uint256 public constant FEE_BPS = 30; // 0.3% fee

    // LP token
    address public lpToken;

    constructor(address _tokenA, address _tokenB, address _dex) {
        tokenA = _tokenA;
        tokenB = _tokenB;
        dex = _dex;

        // Deploy LP token
        lpToken = address(new LiquidityToken(address(this), "SimpleDEX LP", "SDLP"));

        // Approve the DEX contract to manage the tokens
        IERC20(_tokenA).approve(dex, type(uint256).max);
        IERC20(_tokenB).approve(dex, type(uint256).max);
    }

    function getReserves() public view returns (uint256 reserveA, uint256 reserveB) {
        return (IERC20(tokenA).balanceOf(address(this)), IERC20(tokenB).balanceOf(address(this)));
    }

    function addLiquidity(address _tokenA, address _tokenB, uint256 amountA, uint256 amountB) public {
        require(_tokenA == tokenA && _tokenB == tokenB, "Invalid token order.");
        require(msg.sender == dex, "Only DEX can call this.");

        uint256 reserveA = IERC20(tokenA).balanceOf(address(this));
        uint256 reserveB = IERC20(tokenB).balanceOf(address(this));

        uint256 totalLpSupply = LiquidityToken(lpToken).totalSupply();

        uint256 lpTokensToMint;
        if (totalLpSupply == 0) {
            // First liquidity provider, mint based on initial amounts
            lpTokensToMint = Math.sqrt(amountA * amountB); // Simplified for hackathon
        } else {
            // Mint proportionally to existing liquidity
            lpTokensToMint = (amountA * totalLpSupply) / reserveA;
            if (lpTokensToMint > (amountB * totalLpSupply) / reserveB) {
                lpTokensToMint = (amountB * totalLpSupply) / reserveB;
            }
        }

        require(lpTokensToMint > 0, "No LP tokens minted.");

        LiquidityToken(lpToken).mint(msg.sender, lpTokensToMint);
        emit LiquidityAdded(tokenA, tokenB, amountA, amountB);
    }

    function removeLiquidity(address _tokenA, address _tokenB, uint256 amountA, uint256 amountB) public {
        require(_tokenA == tokenA && _tokenB == tokenB, "Invalid token order.");
        require(msg.sender == dex, "Only DEX can call this.");

        uint256 lpTokensBurned = LiquidityToken(lpToken).burnFrom(msg.sender, amountA); // Simplified: burning LP tokens based on one asset amount
        // In a real scenario, you'd burn LP tokens and distribute based on the proportion of LP tokens held.

        uint256 reserveA = IERC20(tokenA).balanceOf(address(this));
        uint256 reserveB = IERC20(tokenB).balanceOf(address(this));

        uint256 amountOutA = (lpTokensBurned * reserveA) / LiquidityToken(lpToken).totalSupply();
        uint256 amountOutB = (lpTokensBurned * reserveB) / LiquidityToken(lpToken).totalSupply();

        require(amountOutA <= amountA && amountOutB <= amountB, "Sufficient liquidity not available for removal.");

        IERC20(tokenA).transfer(msg.sender, amountOutA);
        IERC20(tokenB).transfer(msg.sender, amountOutB);

        emit LiquidityRemoved(tokenA, tokenB, amountOutA, amountOutB);
    }

    function swap(address _tokenIn, address _tokenOut, uint256 _amountIn) public {
        require(_tokenIn == tokenA || _tokenIn == tokenB, "Invalid tokenIn.");
        require(_tokenOut == tokenA || _tokenOut == tokenB, "Invalid tokenOut.");
        require(_tokenIn != _tokenOut, "Cannot swap with the same token.");
        require(msg.sender == dex, "Only DEX can call this.");

        (uint256 reserveIn, uint256 reserveOut) = (_tokenIn == tokenA)
            ? getReserves()
            : (getReserves().1, getReserves().0);

        uint256 feeAmount = (_amountIn * FEE_BPS) / 10000;
        uint256 amountAfterFee = _amountIn - feeAmount;

        require(amountAfterFee > 0, "Amount after fee is zero.");

        // k = x * y invariant calculation
        uint256 invariant = reserveIn * reserveOut;
        uint256 newReserveIn = reserveIn + amountAfterFee;
        uint256 amountOut = (invariant / newReserveIn) - reserveOut;

        require(amountOut > 0, "Swap would result in zero output.");
        require(amountOut <= IERC20(_tokenOut).balanceOf(address(this)), "Insufficient output reserve.");

        IERC20(_tokenOut).transfer(msg.sender, amountOut);

        // Update reserves (implicitly by transfers)
        // The fee collected is implicitly added to the reserves in the next swap.
        // A more advanced contract would handle fee distribution or compounding.

        emit SwapExecuted(_tokenIn, _tokenOut, _amountIn, amountOut);
    }

    // Fallback function to receive Ether if needed
    receive() external payable {}
}

contract LiquidityToken is IERC20, Ownable {
    string private _name;
    string private _symbol;
    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    address public immutable ownerPair; // The Pair contract that owns this LP token

    constructor(address _ownerPair, string memory name_, string memory symbol_) {
        ownerPair = _ownerPair;
        _name = name_;
        _symbol = symbol_;
    }

    function name() public view virtual override returns (string memory) {
        return _name;
    }

    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, msg.sender, _allowances[sender][msg.sender] - amount);
        return true;
    }

    function mint(address to, uint256 amount) public virtual {
        require(msg.sender == ownerPair, "Only the owner pair can mint.");
        _mint(to, amount);
    }

    function burn(uint256 amount) public virtual {
        _burn(msg.sender, amount);
    }

    function burnFrom(address account, uint256 amount) public virtual returns (uint256) {
        // This is a simplified burnFrom for the Pair contract.
        // A real implementation would check allowances.
        uint256 currentAmount = amount; // For simplicity, assume allowance is granted.
        _burn(account, currentAmount);
        return currentAmount;
    }

    function _transfer(address sender, address recipient, uint256 amount) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(sender, recipient, amount);

        uint256 senderBalance = _balances[sender];
        require(senderBalance >= amount, "ERC20: transfer amount exceeds balance");
        _balances[sender] = senderBalance - amount;
        _balances[recipient] += amount;

        emit Transfer(sender, recipient, amount);
    }

    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        _balances[account] = accountBalance - amount;
        _totalSupply -= amount;

        emit Transfer(account, address(0), amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual {}
}