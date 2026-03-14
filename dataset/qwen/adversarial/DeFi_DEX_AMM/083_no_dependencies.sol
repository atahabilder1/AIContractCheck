// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract DeFiDEX {
    address public tokenA;
    address public tokenB;

    uint256 public reserveA;
    uint256 public reserveB;

    uint256 public totalLiquidity;
    mapping(address => uint256) public liquidity;

    event TokenDeposit(address indexed user, uint256 amountA, uint256 amountB);
    event TokenWithdrawal(address indexed user, uint256 amountA, uint256 amountB);
    event Trade(address indexed user, address indexed inputToken, address indexed outputToken, uint256 inputAmount, uint256 outputAmount);

    constructor(address _tokenA, address _tokenB) {
        tokenA = _tokenA;
        tokenB = _tokenB;
    }

    function deposit(uint256 _amountA, uint256 _amountB) external {
        require(_amountA > 0 && _amountB > 0, "Amounts must be greater than zero");

        IERC20(tokenA).transferFrom(msg.sender, address(this), _amountA);
        IERC20(tokenB).transferFrom(msg.sender, address(this), _amountB);

        uint256 liquidityMinted;
        if (totalLiquidity == 0) {
            liquidityMinted = _amountA * _amountB;
        } else {
            liquidityMinted = min(_amountA * totalLiquidity / reserveA, _amountB * totalLiquidity / reserveB);
        }

        liquidity[msg.sender] += liquidityMinted;
        totalLiquidity += liquidityMinted;

        reserveA += _amountA;
        reserveB += _amountB;

        emit TokenDeposit(msg.sender, _amountA, _amountB);
    }

    function withdraw(uint256 _liquidityAmount) external {
        require(_liquidityAmount > 0, "Liquidity amount must be greater than zero");
        require(liquidity[msg.sender] >= _liquidityAmount, "Insufficient liquidity");

        uint256 amountA = (_liquidityAmount * reserveA) / totalLiquidity;
        uint256 amountB = (_liquidityAmount * reserveB) / totalLiquidity;

        liquidity[msg.sender] -= _liquidityAmount;
        totalLiquidity -= _liquidityAmount;

        IERC20(tokenA).transfer(msg.sender, amountA);
        IERC20(tokenB).transfer(msg.sender, amountB);

        reserveA -= amountA;
        reserveB -= amountB;

        emit TokenWithdrawal(msg.sender, amountA, amountB);
    }

    function swap(address _inputToken, address _outputToken, uint256 _inputAmount) external {
        require(_inputAmount > 0, "Input amount must be greater than zero");
        require((_inputToken == tokenA && _outputToken == tokenB) || (_inputToken == tokenB && _outputToken == tokenA), "Invalid tokens");

        IERC20(_inputToken).transferFrom(msg.sender, address(this), _inputAmount);

        uint256 inputReserve = _inputToken == tokenA ? reserveA : reserveB;
        uint256 outputReserve = _inputToken == tokenA ? reserveB : reserveA;

        uint256 outputAmount = (_inputAmount * outputReserve) / (inputReserve + _inputAmount);
        require(outputAmount > 0, "Output amount must be greater than zero");

        if (_outputToken == tokenA) {
            IERC20(tokenA).transfer(msg.sender, outputAmount);
            reserveA += _inputAmount;
            reserveB -= outputAmount;
        } else {
            IERC20(tokenB).transfer(msg.sender, outputAmount);
            reserveB += _inputAmount;
            reserveA -= outputAmount;
        }

        emit Trade(msg.sender, _inputToken, _outputToken, _inputAmount, outputAmount);
    }

    function min(uint256 x, uint256 y) internal pure returns (uint256) {
        return x <= y ? x : y;
    }
}

interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
}