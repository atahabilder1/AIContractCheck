// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-solidity/contracts/token/ERC1155/ERC1155.sol";

contract InGameAssets is ERC1155 {
    // Mapping of token type to rarity level
    mapping(uint256 => uint256) private _rarity;

    // Mapping of token type to the number of tokens in circulation
    mapping(uint256 => uint256) private _circulation;

    // Mapping of token type to the total supply of tokens
    mapping(uint256 => uint256) private _totalSupply;

    constructor() public {
        // Set the contract owner as the minter
        _minter = msg.sender;
    }

    function createTokenType(string memory name, uint256 rarity, uint256 supply) public {
        // Check if the caller is the contract owner
        require(msg.sender == _minter, "Only the contract owner can create new token types");

        // Generate a new token type ID
        uint256 tokenTypeId = _totalSupply[name];

        // Set the rarity level for the new token type
        _rarity[tokenTypeId] = rarity;

        // Set the total supply for the new token type
        _totalSupply[tokenTypeId] = supply;

        // Mint the new token type
        _mint(msg.sender, tokenTypeId, supply);
    }

    function getTokenType(uint256 tokenTypeId) public view returns (string memory name, uint256 rarity, uint256 supply) {
        // Check if the token type ID exists
        require(_totalSupply[tokenTypeId] > 0, "Token type not found");

        // Return the name, rarity, and supply for the token type
        name = _name[tokenTypeId];
        rarity = _rarity[tokenTypeId];
        supply = _totalSupply[tokenTypeId];
    }

    function getTokenTypeCount() public view returns (uint256) {
        // Return the total number of token types
        return _totalSupply.length;
    }

    function getTokenTypeId(string memory name) public view returns (uint256) {
        // Check if the token type name exists
        require(_name[name] > 0, "Token type not found");

        // Return the token type ID for the given name
        return _name[name];
    }

    function getTokenTypeName(uint256 tokenTypeId) public view returns (string memory) {
        // Check if the token type ID exists
        require(_totalSupply[tokenTypeId] > 0, "Token type not found");

        // Return the name for the given token type ID
        return _name[tokenTypeId];
    }

    function mint(address to, uint256 tokenTypeId, uint256 amount) public {
        // Check if the caller is the contract owner
        require(msg.sender == _minter, "Only the contract owner can mint new tokens");

        // Check if the token type ID exists
        require(_totalSupply[tokenTypeId] > 0, "Token type not found");

        // Check if the amount is greater than the total supply for the token type
        require(amount <= _totalSupply[tokenTypeId], "Amount exceeds total supply");

        // Mint the new tokens
        _mint(to, tokenTypeId, amount);
    }

    function burn(address from, uint256 tokenTypeId, uint256 amount) public {
        // Check if the caller is the contract owner
        require(msg.sender == _minter, "Only the contract owner can burn tokens");

        // Check if the token type ID exists
        require(_totalSupply[tokenTypeId] > 0, "Token type not found");

        // Check if the amount is greater than the total supply for the token type
        require(amount <= _totalSupply[tokenTypeId], "Amount exceeds total supply");

        // Burn the tokens
        _burn(from, tokenTypeId, amount);
    }

    function transfer(address to, uint256 tokenTypeId, uint256 amount) public {
        // Check if the caller is the contract owner
        require(msg.sender == _minter, "Only the contract owner can transfer tokens");

        // Check if the token type ID exists
        require(_totalSupply[tokenTypeId] > 0, "Token type not found");

        // Check if the amount is greater than the total supply for the token type
        require(amount <= _totalSupply[tokenTypeId], "Amount exceeds total supply");

        // Transfer the tokens
        _transfer(msg.sender, to, tokenTypeId, amount);
    }
}