// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract GameToken is ERC1155, Ownable {

    uint256 public constant SWORD = 0;
    uint256 public constant SHIELD = 1;
    uint256 public constant GOLD = 2;
    uint256 public constant GEM = 3;

    constructor() ERC1155("https://game.example.com/metadata/{id}.json") {
        // Mint initial supply for some items
        _mint(msg.sender, SWORD, 10, "");
        _mint(msg.sender, SHIELD, 5, "");
        _mint(msg.sender, GOLD, 1000000, "");
        _mint(msg.sender, GEM, 10000, "");
    }

    function mint(address to, uint256 id, uint256 amount, bytes memory data) public onlyOwner {
        _mint(to, id, amount, data);
    }

    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) public onlyOwner {
        _mintBatch(to, ids, amounts, data);
    }

    function burn(uint256 id, uint256 amount) public {
        _burn(msg.sender, id, amount);
    }

    function burnBatch(uint256[] memory ids, uint256[] memory amounts) public {
        _burnBatch(msg.sender, ids, amounts);
    }
}