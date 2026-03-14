// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract AMM {
    // Variables for the AMM
    uint256 public constant INITIAL_SUPPLY = 1000000; // Initial supply of the token
    uint256 public totalLiquidity; // Total liquidity in the pool
    uint256 public totalSupply; // Total supply of the token
    mapping(address => uint256) public balances; // Balances of token holders
    mapping(address => mapping(address => uint256)) public allowances; // Allowances for token transfers

    // Variables for the bonding curve
    enum CurveType { Linear, Exponential }
    CurveType public curveType;
    uint256 public curveSlope; // Slope for linear curve, base for exponential curve
    uint256 public curveIntercept; // Intercept for linear curve, exponent for exponential curve

    // Token creation and initial distribution
    constructor(CurveType _curveType, uint256 _slope, uint256 _intercept) {
        curveType = _curveType;
        curveSlope = _slope;
        curveIntercept = _intercept;
        totalLiquidity = INITIAL_SUPPLY;
        balances[msg.sender] = INITIAL_SUPPLY;
        totalSupply = INITIAL_SUPPLY;
    }

    // Function to add liquidity
    function addLiquidity(uint256 amount) public payable {
        require(msg.value == getPrice(amount), "Incorrect amount of ETH sent");
        totalLiquidity += amount;
        balances[msg.sender] += amount;
        totalSupply += amount;
    }

    // Function to remove liquidity
    function removeLiquidity(uint256 amount) public {
        require(balances[msg.sender] >= amount, "Not enough liquidity");
        totalLiquidity -= amount;
        balances[msg.sender] -= amount;
        totalSupply -= amount;
        payable(msg.sender).transfer(getPrice(amount));
    }

    // Function to get the current price based on the bonding curve
    function getPrice(uint256 amount) public view returns (uint256) {
        if (curveType == CurveType.Linear) {
            return curveSlope * amount + curveIntercept;
        } else if (curveType == CurveType.Exponential) {
            return (10 ** 18) * (curveIntercept ** amount);
        }
        revert("Unknown curve type");
    }

    // Standard ERC20 functions
    function transfer(address to, uint256 amount) public returns (bool) {
        require(balances[msg.sender] >= amount, "Not enough tokens");
        balances[msg.sender] -= amount;
        balances[to] += amount;
        return true;
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        allowances[msg.sender][spender] = amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public returns (bool) {
        require(balances[from] >= amount, "Not enough tokens");
        require(allowances[from][msg.sender] >= amount, "Allowance exceeded");
        balances[from] -= amount;
        balances[to] += amount;
        allowances[from][msg.sender] -= amount;
        return true;
    }
}