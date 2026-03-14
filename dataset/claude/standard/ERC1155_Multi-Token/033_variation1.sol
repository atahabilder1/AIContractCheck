// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract GameAssets is ERC1155, Ownable {
    enum Rarity { Common, Uncommon, Rare, Epic, Legendary }

    struct TokenType {
        string name;
        Rarity rarity;
        uint256 maxSupply;
        uint256 totalMinted;
        bool exists;
    }

    uint256 private _nextTokenId;
    mapping(uint256 => TokenType) public tokenTypes;

    event TokenTypeCreated(uint256 indexed tokenId, string name, Rarity rarity, uint256 maxSupply);

    constructor(string memory uri_) ERC1155(uri_) Ownable(msg.sender) {}

    function createTokenType(
        string calldata name,
        Rarity rarity,
        uint256 maxSupply
    ) external onlyOwner returns (uint256) {
        uint256 tokenId = _nextTokenId++;
        tokenTypes[tokenId] = TokenType({
            name: name,
            rarity: rarity,
            maxSupply: maxSupply,
            totalMinted: 0,
            exists: true
        });
        emit TokenTypeCreated(tokenId, name, rarity, maxSupply);
        return tokenId;
    }

    function mint(address to, uint256 tokenId, uint256 amount) external onlyOwner {
        TokenType storage t = tokenTypes[tokenId];
        require(t.exists, "Token type does not exist");
        require(t.totalMinted + amount <= t.maxSupply, "Exceeds max supply");
        t.totalMinted += amount;
        _mint(to, tokenId, amount, "");
    }

    function mintBatch(
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts
    ) external onlyOwner {
        for (uint256 i = 0; i < ids.length; i++) {
            TokenType storage t = tokenTypes[ids[i]];
            require(t.exists, "Token type does not exist");
            require(t.totalMinted + amounts[i] <= t.maxSupply, "Exceeds max supply");
            t.totalMinted += amounts[i];
        }
        _mintBatch(to, ids, amounts, "");
    }

    function setURI(string calldata newuri) external onlyOwner {
        _setURI(newuri);
    }
}