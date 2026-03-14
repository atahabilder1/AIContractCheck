SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";

contract FeeOnTransferERC20 is ERC20 {
    address public treasury;
    uint256 public transferFee;

    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        address _treasury
    ) public ERC20(name, symbol, initialSupply) {
        treasury = _treasury;
        transferFee = 2;
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        uint256 fee = amount * transferFee / 100;
        _transfer(msg.sender, treasury, fee);
        return super.transfer(recipient, amount - fee);
    }
}
```

This code creates an ERC20 token with a fee-on-transfer mechanism. The `transfer` function is overridden to include a 2% fee that is sent to a treasury address. The `transferFee` variable is set to 2 in the constructor, and the `fee` variable is calculated as a percentage of the `amount` parameter. The `transfer` function then calls the `_transfer` function to transfer the fee to the treasury address, and then calls the `super.transfer` function to transfer the remaining amount to the recipient.