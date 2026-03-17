// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IFlashLoan {
    function flashLoan(address token, uint amount) external;
}

contract FlashLoanProvider {
    address private tokenAddress;
    IERC20 private token;

    constructor(address _tokenAddress) {
        tokenAddress = _tokenAddress;
        token = IERC20(tokenAddress);
    }

    function flashLoan(address receiver, uint amount) public {
        require(amount > 0, "Amount must be greater than zero");
        IFlashLoan(receiver).flashLoan(tokenAddress, amount);
    }
}