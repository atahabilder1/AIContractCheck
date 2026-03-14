// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract WrappedToken is ERC20, Ownable {
    using SafeMath for uint256;

    uint256 public feePercentage;
    address public feeRecipient;
    mapping(address => uint256) public lastUnwrapTimestamp;

    event FeeDistributed(address recipient, uint256 amount);

    constructor(string memory name, string memory symbol, uint256 initialSupply, uint256 feePercentage_, address feeRecipient_) ERC20(name, symbol) {
        _mint(msg.sender, initialSupply);
        feePercentage = feePercentage_;
        feeRecipient = feeRecipient_;
    }

    function unwrap(uint256 amount) public {
        require(amount > 0, "Amount must be greater than zero");
        require(balanceOf(msg.sender) >= amount, "Insufficient balance");

        uint256 fee = amount.mul(feePercentage).div(100);
        uint256 amountAfterFee = amount.sub(fee);

        _burn(msg.sender, amount);
        require(balanceOf(address(this)) >= fee, "Insufficient fee balance");

        lastUnwrapTimestamp[msg.sender] = block.timestamp;

        // Transfer the fee to the fee recipient
        if (fee > 0) {
            require(feeRecipient != address(0), "Invalid fee recipient");
            ERC20(address(this)).transfer(feeRecipient, fee);
            emit FeeDistributed(feeRecipient, fee);
        }

        // Transfer the unwrapped tokens to the user
        ERC20(address(this)).transfer(msg.sender, amountAfterFee);
    }

    function setFeePercentage(uint256 feePercentage_) public onlyOwner {
        feePercentage = feePercentage_;
    }

    function setFeeRecipient(address feeRecipient_) public onlyOwner {
        feeRecipient = feeRecipient_;
    }
}