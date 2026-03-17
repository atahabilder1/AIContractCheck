// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract WrappedToken is Ownable {
    using ECDSA for bytes32;

    IERC20 public underlying;
    uint256 public totalSupply;

    constructor(IERC20 _underlying) {
        underlying = _underlying;
    }

    function deposit(uint256 amount) external {
        require(amount > 0, "Amount must be greater than zero");
        underlying.transferFrom(msg.sender, address(this), amount);
        totalSupply += amount;
        _mint(msg.sender, amount);
    }

    function withdraw(uint256 amount) external {
        require(amount > 0, "Amount must be greater than zero");
        require(_burn(msg.sender, amount), "Insufficient balance");
        totalSupply -= amount;
        underlying.transfer(msg.sender, amount);
    }

    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external {
        require(deadline >= block.timestamp, "Permit expired");
        bytes32 digest = _hashTypedDataV4(keccak256(abi.encode(
            "\x19\x01",
            domainSeparator(),
            keccak256(abi.encode(
                ERC20Permit(owner, spender, value, deadline, name(), version())
            ))
        )));
        require(address(this).recover(digest, v, r, s) == owner, "Invalid signature");
        _approve(owner, spender, value);
    }

    function flashMint(address receiver, uint256 amount) external {
        require(_msgSender() != address(this), "Flash mint not allowed from this contract");
        totalSupply += amount;
        _mint(receiver, amount);
    }

    // ERC20 implementation omitted for brevity (see OpenZeppelin's ERC20 contracts)
}