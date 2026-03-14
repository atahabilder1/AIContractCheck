// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Bridge is Ownable {
    using SafeERC20 for IERC20;
    using Address for address;

    address public admin;

    struct Fee {
        uint256 rate; // Fee rate per unit
        uint256 minFee; // Minimum fee
    }

    mapping(address => Fee) public fees;

    event FeeSet(address indexed token, uint256 rate, uint256 minFee);
    event BridgeTransfer(address indexed token, uint256 amount, address indexed to, uint256 fee);
    event BridgeTransferETH(uint256 amount, address indexed to, uint256 fee);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can call this function");
        _;
    }

    constructor(address _admin) {
        admin = _admin;
    }

    function setFee(address token, uint256 rate, uint256 minFee) external onlyAdmin {
        fees[token] = Fee(rate, minFee);
        emit FeeSet(token, rate, minFee);
    }

    function transfer(address token, uint256 amount, address to) external payable {
        require(amount > 0, "Amount must be greater than zero");
        Fee memory fee = fees[token];
        uint256 feeAmount = (amount * fee.rate) / 100;
        if (feeAmount < fee.minFee) {
            feeAmount = fee.minFee;
        }
        if (token == address(0)) {
            require(msg.value >= amount + feeAmount, "Insufficient ETH sent");
            (bool success, ) = to.call{value: amount}("");
            require(success, "ETH transfer failed");
            emit BridgeTransferETH(amount, to, feeAmount);
        } else {
            require(msg.value == 0, "ETH should not be sent with ERC20 transfer");
            IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
            IERC20(token).safeTransfer(to, amount - feeAmount);
            emit BridgeTransfer(token, amount, to, feeAmount);
        }
    }

    function withdrawFee(address token) external onlyAdmin {
        Fee memory fee = fees[token];
        uint256 feeBalance = address(this).balance;
        if (token != address(0)) {
            feeBalance = IERC20(token).balanceOf(address(this));
        }
        if (feeBalance > 0) {
            if (token == address(0)) {
                (bool success, ) = msg.sender.call{value: feeBalance}("");
                require(success, "ETH transfer failed");
            } else {
                IERC20(token).safeTransfer(msg.sender, feeBalance);
            }
        }
    }

    receive() external payable {}
}