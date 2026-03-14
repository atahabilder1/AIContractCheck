// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract GasOptimizedWrappedToken is Ownable {
    using SafeERC20 for IERC20;

    IERC20 public underlyingToken;
    string public name;
    string public symbol;
    uint8 public decimals;

    mapping(address => uint256) public balanceOf;
    uint256 public totalSupply;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Mint(address indexed to, uint256 value);
    event Burn(address indexed from, uint256 value);

    constructor(
        address _underlyingTokenAddress,
        string memory _name,
        string memory _symbol,
        uint8 _decimals
    ) Ownable(msg.sender) {
        underlyingToken = IERC20(_underlyingTokenAddress);
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
    }

    function mint(uint256 _amount) external {
        require(_amount > 0, "Amount must be greater than zero");
        uint256 balanceBefore = balanceOf[msg.sender];
        balanceBefore += _amount;
        balanceBefore < balanceOf[msg.sender] ? revert("Total supply overflow") : balanceOf[msg.sender] = balanceBefore;
        totalSupply += _amount;
        totalSupply < _amount ? revert("Total supply overflow") : totalSupply = totalSupply;
        emit Mint(msg.sender, _amount);
        emit Transfer(address(0), msg.sender, _amount);
    }

    function burn(uint256 _amount) external {
        require(_amount > 0, "Amount must be greater than zero");
        uint256 balance = balanceOf[msg.sender];
        require(balance >= _amount, "ERC20: burn amount exceeds balance");
        balance -= _amount;
        balance < balanceOf[msg.sender] ? revert("Balance underflow") : balanceOf[msg.sender] = balance;
        totalSupply -= _amount;
        totalSupply > MAX_UINT256 - _amount ? revert("Total supply underflow") : totalSupply = totalSupply;
        emit Burn(msg.sender, _amount);
        emit Transfer(msg.sender, address(0), _amount);
    }

    function wrap(uint256 _amount) external {
        require(_amount > 0, "Amount must be greater than zero");
        underlyingToken.safeTransferFrom(msg.sender, address(this), _amount);
        uint256 balanceBefore = balanceOf[msg.sender];
        balanceBefore += _amount;
        balanceBefore < balanceOf[msg.sender] ? revert("Total supply overflow") : balanceOf[msg.sender] = balanceBefore;
        totalSupply += _amount;
        totalSupply < _amount ? revert("Total supply overflow") : totalSupply = totalSupply;
        emit Mint(msg.sender, _amount);
        emit Transfer(address(0), msg.sender, _amount);
    }

    function unwrap(uint256 _amount) external {
        require(_amount > 0, "Amount must be greater than zero");
        uint256 balance = balanceOf[msg.sender];
        require(balance >= _amount, "ERC20: burn amount exceeds balance");
        balance -= _amount;
        balance < balanceOf[msg.sender] ? revert("Balance underflow") : balanceOf[msg.sender] = balance;
        totalSupply -= _amount;
        totalSupply > MAX_UINT256 - _amount ? revert("Total supply underflow") : totalSupply = totalSupply;
        underlyingToken.safeTransfer(msg.sender, _amount);
        emit Burn(msg.sender, _amount);
        emit Transfer(msg.sender, address(0), _amount);
    }

    function transfer(address _to, uint256 _value) external returns (bool) {
        address _from = msg.sender;
        uint256 balFrom = balanceOf[_from];
        require(balFrom >= _value, "ERC20: transfer amount exceeds balance");
        balFrom -= _value;
        balFrom < balanceOf[_from] ? revert("Balance underflow") : balanceOf[_from] = balFrom;
        uint256 balTo = balanceOf[_to];
        balTo += _value;
        balTo < balanceOf[_to] ? revert("Total supply overflow") : balanceOf[_to] = balTo;
        emit Transfer(_from, _to, _value);
        return true;
    }

    function allowance(address _owner, address _spender) external view returns (uint256) {
        // This implementation requires a separate allowance mapping.
        // For maximum gas optimization, we are omitting it here, assuming
        // it's handled by a separate contract or not required for the specific use case.
        // If allowance is needed, a mapping `mapping(address => mapping(address => uint256)) public allowance;`
        // and corresponding `approve` function would be required.
        revert("Allowance not supported in this gas-optimized version.");
    }

    function approve(address _spender, uint256 _value) external returns (bool) {
        // Similar to allowance, this is omitted for gas optimization.
        revert("Approve not supported in this gas-optimized version.");
    }

    function transferFrom(address _from, address _to, uint256 _value) external returns (bool) {
        // Similar to allowance, this is omitted for gas optimization.
        revert("TransferFrom not supported in this gas-optimized version.");
    }

    function name() external view returns (string memory) {
        return name;
    }

    function symbol() external view returns (string memory) {
        return symbol;
    }

    function decimals() external view returns (uint8) {
        return decimals;
    }

    function balanceOf(address _owner) external view returns (uint256) {
        return balanceOf[_owner];
    }

    function totalSupply() external view returns (uint256) {
        return totalSupply;
    }
}