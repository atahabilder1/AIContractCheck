// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MultiToken is ERC1155 {
    constructor() ERC1155("MultiToken") {}

    function mint(address to, uint256 id, uint256 amount) public onlyOwner {
        _mint(to, id, amount, "");
    }

    function burn(address from, uint256 id, uint256 amount) public onlyOwner {
        _burn(from, id, amount);
    }
}