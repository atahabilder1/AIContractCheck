// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract WrappedToken is ERC20, Ownable {
    uint256 public constant FEE_PERCENTAGE = 1; // 1% fee on unwrapping
    address public feeDistributor;

    constructor(address _feeDistributor) ERC20("Wrapped Token", "WTKN") {
        feeDistributor = _feeDistributor;
    }

    function wrap(uint256 amount) external {
        require(amount > 0, "Amount must be greater than zero");
        _mint(msg.sender, amount);
    }

    function unwrap(uint256 amount) external {
        require(amount > 0, "Amount must be greater than zero");
        require(balanceOf(msg.sender) >= amount, "Insufficient balance");

        uint256 fee = (amount * FEE_PERCENTAGE) / 100;
        uint256 amountAfterFee = amount - fee;

        _burn(msg.sender, amount);
        _transfer(feeDistributor, fee);
        payable(msg.sender).transfer(amountAfterFee);
    }

    function setFeeDistributor(address newFeeDistributor) external onlyOwner {
        require(newFeeDistributor != address(0), "Invalid address");
        feeDistributor = newFeeDistributor;
    }
}