```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract SimpleAMM {
    uint256 public reserveA;
    uint256 public reserveB;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;

    event Swap(address indexed sender, uint256 amountAIn, uint256 amountBIn, uint256 amountAOut, uint256 amountBOut, address indexed to);
    event Mint(address indexed sender, uint256 amountA, uint256 amountB, uint256 liquidity, address indexed to);
    event Burn(address indexed sender, uint256 amountA, uint256 amountB, uint256 liquidity, address indexed to);

    function mint(uint256 _amountA, uint256 _amountB) external {
        require(_amountA > 0 && _amountB > 0, "Amounts must be greater than 0");
        uint256 liquidity;
        if (totalSupply == 0) {
            liquidity = sqrt(_amountA * _amountB);
        } else {
            liquidity = min(_amountA * totalSupply / reserveA, _amountB * totalSupply / reserveB);
        }
        require(liquidity > 0, "Liquidity must be greater than 0");
        balanceOf[msg.sender] += liquidity;
        totalSupply += liquidity;
        reserveA += _amountA;
        reserveB += _amountB;
        emit Mint(msg.sender, _amountA, _amountB, liquidity, msg.sender);
    }

    function burn(uint256 _liquidity) external {
        require(_liquidity > 0, "Liquidity must be greater than 0");
        require(balanceOf[msg.sender] >= _liquidity, "Insufficient balance");
        uint256 amountA = _liquidity * reserveA / totalSupply;
        uint256 amountB = _liquidity * reserveB / totalSupply;
        balanceOf[msg.sender] -= _liquidity;
        totalSupply -= _liquidity;
        reserveA -= amountA;
        reserveB -= amountB;
        emit Burn(msg.sender, amountA, amountB, _liquidity, msg.sender);
    }

    function swap(uint256 _amountAIn, uint256 _amountBIn) external {
        require(_amountAIn > 0 || _amountBIn > 0, "Amounts must be greater than 0");
        uint256 amountAOut;
        uint256 amountBOut;
        if (_amountAIn > 0) {
            amountBOut = getAmountOut(_amountAIn, reserveA, reserveB);
            reserveA += _amountAIn;
            reserveB -= amountBOut;
        } else {
            amountAOut = getAmountOut(_amountBIn, reserveB, reserveA);
            reserveB += _amountBIn;
            reserveA -= amountAOut;
        }
        emit Swap(msg.sender, _amountAIn, _amountBIn, amountAOut, amountBOut, msg.sender);
    }

    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) internal pure returns (uint256) {
        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * 1000 + amountInWithFee;
        return numerator / denominator;
    }

    function sqrt(uint256 x) internal pure returns (uint256) {
        if (x == 0) return 0;
        uint256 xx = x;
        uint256 r = 1;
        if (xx >= 0x10000000000000000000000000000000