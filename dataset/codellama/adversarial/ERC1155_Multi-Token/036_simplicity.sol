// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MultiToken is ERC1155 {
    mapping(uint256 => uint256) private _balances;
    mapping(uint256 => address) private _owners;

    function mint(address to, uint256 amount) public {
        require(amount > 0, "Amount must be greater than 0");
        _balances[to] += amount;
        _owners[to] = to;
    }

    function burn(uint256 amount) public {
        require(amount > 0, "Amount must be greater than 0");
        _balances[msg.sender] -= amount;
        _owners[msg.sender] = address(0);
    }

    function balanceOf(address owner) public view returns (uint256) {
        return _balances[owner];
    }

    function ownerOf(uint256 tokenId) public view returns (address) {
        return _owners[tokenId];
    }
}