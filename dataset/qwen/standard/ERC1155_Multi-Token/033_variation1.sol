// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract InGameAssets is ERC1155, Ownable {
    uint256 private _currentTokenId;

    enum Rarity {
        COMMON,
        RARE,
        EPIC,
        LEGENDARY
    }

    mapping(uint256 => Rarity) public tokenRarity;

    constructor() ERC1155("") {}

    function createNewAsset(uint256 initialSupply, Rarity rarity) external onlyOwner {
        uint256 newTokenId = _currentTokenId;
        _mint(msg.sender, newTokenId, initialSupply, "");
        tokenRarity[newTokenId] = rarity;
        _currentTokenId++;
    }

    function mintMore(uint256 id, uint256 additionalSupply) external onlyOwner {
        require(tokenRarity[id] != Rarity(0), "Token does not exist");
        _mint(msg.sender, id, additionalSupply, "");
    }

    function uri(uint256 _id) public view override returns (string memory) {
        return string(abi.encodePacked(super.uri(_id), Strings.toString(_id)));
    }
}