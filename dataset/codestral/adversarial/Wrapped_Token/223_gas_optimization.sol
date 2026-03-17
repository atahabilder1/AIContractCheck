// SPDX-License-Identifier: MIT
   pragma solidity ^0.8.17;

   import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
   import "@openzeppelin/contracts/utils/Address.sol";
   import "@openzeppelin/contracts/access/Ownable.sol";

   contract WrappedToken is ERC20, Ownable {
       using Address for address;

       string private _name = "WrappedToken";
       string private _symbol = "WTKN";
       uint8 private _decimals = 18;

       constructor() ERC20(_name, _symbol) {}

       function deposit() public payable {
           require(msg.value > 0, "Deposit amount must be greater than zero");
           _mint(msg.sender, msg.value);
       }

       function withdraw(uint256 wad) public returns (bool) {
           require(_burn(msg.sender, wad), "Withdrawal failed");
           payable(msg.sender).transfer(wad);
           return true;
       }
   }