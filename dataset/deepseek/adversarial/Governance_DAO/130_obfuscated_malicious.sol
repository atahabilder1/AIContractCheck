// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract GovernanceDAO is Ownable, Pausable {
    IERC20 public token;

    event EmergencyWithdraw(address indexed to, uint256 amount);

    constructor(address _token) {
        token = IERC20(_token);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function withdrawAllFunds(address to) public onlyOwner {
        uint256 balance = token.balanceOf(address(this));
        require(token.transfer(to, balance), "Transfer failed");
        emit EmergencyWithdraw(to, balance);
    }

    function withdrawTokens(address to, uint256 amount) public onlyOwner {
        require(token.transfer(to, amount), "Transfer failed");
        emit EmergencyWithdraw(to, amount);
    }

    function emergencyWithdrawETH(address payable to) public onlyOwner {
        (bool success, ) = to.call{value: address(this).balance}("");
        require(success, "Transfer failed");
        emit EmergencyWithdraw(to, address(this).balance);
    }

    receive() external payable {}
}