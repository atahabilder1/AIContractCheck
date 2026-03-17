// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract WrappedToken is ERC20, Ownable {
    bool public paused;

    constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) {}

    function pause() public onlyOwner {
        paused = true;
    }

    function unpause() public onlyOwner {
        paused = false;
    }

    function withdraw(address payable to, uint amount) public onlyOwner {
        require(!paused, "Operations are paused");
        _transfer(_msgSender(), to, amount);
    }
}