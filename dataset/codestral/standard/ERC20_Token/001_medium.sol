// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MyToken is ERC20, Ownable {
    mapping(address => bool) public blacklisted;

    constructor() ERC20("MyToken", "MTK") {}

    function mint(address account, uint256 amount) external onlyOwner {
        _mint(account, amount);
    }

    function burn(uint256 amount) external {
        require(_balanceOf[msg.sender] >= amount, "Insufficient balance");
        _burn(msg.sender, amount);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function blacklist(address account) external onlyOwner {
        blacklisted[account] = true;
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal override {
        super._beforeTokenTransfer(from, to, amount);
        require(!blacklisted[from], "Sender is blacklisted");
        require(!blacklisted[to], "Receiver is blacklisted");
    }
}