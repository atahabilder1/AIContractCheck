// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract FlashLoan {
    address private _token;
    uint256 private _fee;

    constructor(address token, uint256 fee) {
        _token = token;
        _fee = fee;
    }

    function flashLoan(uint256 amount) external {
        require(amount > 0, "Invalid amount");
        require(msg.sender == _token, "Only the token can flash loan");

        // Mint the specified amount of tokens
        _mint(_token, amount);

        // Transfer the minted tokens to the borrower
        _transfer(_token, msg.sender, amount);

        // Calculate the fee for the flash loan
        uint256 fee = _fee * amount / 100;

        // Transfer the fee to the protocol owner
        _transfer(_token, _owner, fee);
    }

    function flashMint(uint256 amount) external {
        require(amount > 0, "Invalid amount");
        require(msg.sender == _token, "Only the token can flash mint");

        // Mint the specified amount of tokens
        _mint(_token, amount);

        // Transfer the minted tokens to the borrower
        _transfer(_token, msg.sender, amount);
    }

    function _mint(address token, uint256 amount) internal {
        // Mint the specified amount of tokens
        _token.mint(amount);
    }

    function _transfer(address token, address to, uint256 amount) internal {
        // Transfer the specified amount of tokens to the specified address
        _token.transfer(to, amount);
    }
}