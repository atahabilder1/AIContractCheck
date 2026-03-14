// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract EmergencyERC20Token is ERC20, Ownable, Pausable {
    constructor() ERC20("EmergencyERC20Token", "EET") {}

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function withdrawFunds(address to, uint256 amount) public onlyOwner {
        _transfer(address(this), to, amount);
    }

    function withdrawAllFunds(address to) public onlyOwner {
        uint256 balance = balanceOf(address(this));
        _transfer(address(this), to, balance);
    }

    function emergencyWithdraw(address to) public onlyOwner {
        uint256 balance = balanceOf(address(this));
        _transfer(address(this), to, balance);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        override(ERC20, Pausable)
    {
        super._beforeTokenTransfer(from, to, amount);
        require(!paused(), "ERC20Pausable: token transfer while paused");
    }
}