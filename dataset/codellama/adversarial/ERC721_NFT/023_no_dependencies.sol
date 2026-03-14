SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract ERC721 {
    string public name;
    string public symbol;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(uint256 => address) public ownerOf;
    mapping(uint256 => string) public tokenURI;
    mapping(uint256 => bool) public burned;

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);
    event Burn(uint256 indexed tokenId);

    constructor(string memory _name, string memory _symbol) public {
        name = _name;
        symbol = _symbol;
    }

    function mint(address to, string memory tokenURI) public {
        require(msg.sender == ownerOf[to], "Only the owner of the contract can mint new tokens");
        require(!burned[to], "Cannot mint a token that has been burned");

        totalSupply++;
        balanceOf[to]++;
        ownerOf[totalSupply] = to;
        tokenURI[totalSupply] = tokenURI;

        emit Transfer(address(0), to, totalSupply);
    }

    function burn(uint256 tokenId) public {
        require(msg.sender == ownerOf[tokenId], "Only the owner of the token can burn it");
        require(!burned[tokenId], "Cannot burn a token that has already been burned");

        totalSupply--;
        balanceOf[ownerOf[tokenId]]--;
        ownerOf[tokenId] = address(0);
        tokenURI[tokenId] = "";

        emit Burn(tokenId);
    }

    function transfer(address to, uint256 tokenId) public {
        require(msg.sender == ownerOf[tokenId], "Only the owner of the token can transfer it");

        balanceOf[ownerOf[tokenId]]--;
        balanceOf[to]++;
        ownerOf[tokenId] = to;

        emit Transfer(msg.sender, to, tokenId);
    }

    function approve(address approved, uint256 tokenId) public {
        require(msg.sender == ownerOf[tokenId], "Only the owner of the token can approve it");

        emit Approval(msg.sender, approved, tokenId);
    }

    function setApprovalForAll(address operator, bool approved) public {
        require(msg.sender == ownerOf[operator], "Only the owner of the operator can set approval");

        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function getApproved(uint256 tokenId) public view returns (address) {
        return ownerOf[tokenId];
    }

    function isApprovedForAll(address owner, address operator) public view returns (bool) {
        return ownerOf[owner] == ownerOf[operator];
    }

    function tokenURI(uint256 tokenId) public view returns (string memory) {
        return tokenURI[tokenId];
    }
}