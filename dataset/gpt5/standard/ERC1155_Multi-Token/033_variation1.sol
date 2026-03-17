// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract GameAssets is ERC1155, ERC1155Supply, ERC1155Burnable, Ownable {
    enum Rarity {
        Common,
        Uncommon,
        Rare,
        Epic,
        Legendary
    }

    mapping(uint256 => bool) private _exists;
    mapping(uint256 => Rarity) private _rarityOf;
    mapping(uint256 => string) private _tokenURIs;

    event TokenTypeCreated(
        uint256 indexed id,
        Rarity rarity,
        uint256 initialSupply,
        address indexed to,
        string uri
    );

    constructor(string memory baseURI) ERC1155(baseURI) {}

    function createTokenType(
        uint256 id,
        Rarity rarity,
        uint256 initialSupply,
        address to,
        string memory tokenURI_,
        bytes memory data
    ) external onlyOwner {
        require(!_exists[id], "GameAssets: token type already exists");
        _exists[id] = true;
        _rarityOf[id] = rarity;

        if (bytes(tokenURI_).length != 0) {
            _tokenURIs[id] = tokenURI_;
            emit URI(tokenURI_, id);
        }

        if (initialSupply > 0) {
            _mint(to, id, initialSupply, data);
        }

        emit TokenTypeCreated(id, rarity, initialSupply, to, tokenURI_);
    }

    function setTokenURI(uint256 id, string memory tokenURI_) external onlyOwner {
        require(_exists[id], "GameAssets: nonexistent token type");
        _tokenURIs[id] = tokenURI_;
        emit URI(tokenURI_, id);
    }

    function setBaseURI(string memory newuri) external onlyOwner {
        _setURI(newuri);
    }

    function exists(uint256 id) external view returns (bool) {
        return _exists[id];
    }

    function rarityOf(uint256 id) external view returns (Rarity) {
        require(_exists[id], "GameAssets: nonexistent token type");
        return _rarityOf[id];
    }

    function mintExisting(address to, uint256 id, uint256 amount, bytes memory data) external onlyOwner {
        require(_exists[id], "GameAssets: nonexistent token type");
        _mint(to, id, amount, data);
    }

    function mintBatchExisting(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) external onlyOwner {
        require(ids.length == amounts.length, "GameAssets: length mismatch");
        for (uint256 i = 0; i < ids.length; i++) {
            require(_exists[ids[i]], "GameAssets: nonexistent token type");
        }
        _mintBatch(to, ids, amounts, data);
    }

    function uri(uint256 id) public view override returns (string memory) {
        string memory tUri = _tokenURIs[id];
        if (bytes(tUri).length != 0) {
            return tUri;
        }
        return super.uri(id);
    }

    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal override(ERC1155, ERC1155Supply) {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }
}