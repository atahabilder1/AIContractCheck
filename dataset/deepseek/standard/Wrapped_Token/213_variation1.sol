// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract WrappedRebasingToken is ERC20, ERC20Burnable, Ownable {
    IRebasingToken public immutable underlying;

    constructor(string memory name, string memory symbol, address underlyingToken) ERC20(name, symbol) {
        underlying = IRebasingToken(underlyingToken);
    }

    function totalSupply() public view override returns (uint256) {
        return underlying.totalSupply() / 10**decimals();
    }

    function balanceOf(address account) public view override returns (uint256) {
        return underlying.balanceOf(account) / 10**decimals();
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        uint256 underlyingAmount = amount * 10**decimals();
        bool success = underlying.transferFrom(msg.sender, address(this), underlyingAmount);
        if (success) {
            _burn(msg.sender, amount);
        }
        return success;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        uint256 underlyingAmount = amount * 10**decimals();
        bool success = underlying.transferFrom(sender, recipient, underlyingAmount);
        if (success) {
            _burn(sender, amount);
        }
        return success;
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
        uint256 underlyingAmount = amount * 10**decimals();
        underlying.mint(to, underlyingAmount);
    }

    function burn(uint256 amount) public override {
        _burn(msg.sender, amount);
        uint256 underlyingAmount = amount * 10**decimals();
        underlying.burn(address(this), underlyingAmount);
    }
}

interface IRebasingToken {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function mint(address to, uint256 amount) external;
    function burn(address from, uint256 amount) external;
}