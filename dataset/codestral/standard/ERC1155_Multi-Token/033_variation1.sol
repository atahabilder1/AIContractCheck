// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract GameAssets is ERC1155, Ownable {
    enum RarityLevel { Common, Uncommon, Rare, Legendary }

    struct AssetType {
        string name;
        string description;
        uint256 maxSupply;
        RarityLevel rarity;
    }

    mapping(uint256 => AssetType) public assetTypes;

    function createAssetType(string memory _name, string memory _description, uint256 _maxSupply, RarityLevel _rarity) external onlyOwner {
        uint256 newTokenId = totalSupply() + 1;
        AssetType memory newAssetType = AssetType({
            name: _name,
            description: _description,
            maxSupply: _maxSupply,
            rarity: _rarity
        });
        assetTypes[newTokenId] = newAssetType;
    }
}