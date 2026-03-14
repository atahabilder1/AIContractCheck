// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";

contract NFT is ERC721, ERC721Enumerable, ERC721URIStorage, Ownable, ERC2981 {
    using Counters for Counters.Counter;
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    Counters.Counter private _tokenIdCounter;
    uint256 public maxSupply;
    uint256 public mintPrice;
    bool public revealed;
    string public notRevealedUri;
    bytes32 public merkleRoot;
    mapping(address => bool) public whitelistClaimed;

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _maxSupply,
        uint256 _mintPrice,
        string memory _notRevealedUri
    ) ERC721(_name, _symbol) {
        maxSupply = _maxSupply;
        mintPrice = _mintPrice;
        notRevealedUri = _notRevealedUri;
        revealed = false;
    }

    function mint(uint256 amount) public payable {
        require(totalSupply() + amount <= maxSupply, "Max supply reached");
        require(amount > 0, "Must mint at least one token");
        require(msg.value >= mintPrice.mul(amount), "Insufficient funds sent");

        for (uint256 i = 0; i < amount; i++) {
            _tokenIdCounter.increment();
            _safeMint(msg.sender, _tokenIdCounter.current());
        }
    }

    function whitelistMint(uint256 amount, bytes32[] memory proof) public payable {
        require(totalSupply() + amount <= maxSupply, "Max supply reached");
        require(amount > 0, "Must mint at least one token");
        require(msg.value >= mintPrice.mul(amount), "Insufficient funds sent");

        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        require(MerkleProof.verify(proof, merkleRoot, leaf), "Invalid proof");
        require(!whitelistClaimed[msg.sender], "Address already claimed");

        whitelistClaimed[msg.sender] = true;

        for (uint256 i = 0; i < amount; i++) {
            _tokenIdCounter.increment();
            _safeMint(msg.sender, _tokenIdCounter.current());
        }
    }

    function reveal(string memory revealedUri) public onlyOwner {
        revealed = true;
        notRevealedUri = revealedUri;
    }

    function setMerkleRoot(bytes32 _merkleRoot) public onlyOwner {
        merkleRoot = _merkleRoot;
    }

    function setRoyaltyInfo(address receiver, uint96 royaltyFraction) public onlyOwner {
        _setDefaultRoyalty(receiver, royaltyFraction);
    }

    function _baseURI() internal view override returns (string memory) {
        return revealed ? "" : notRevealedUri;
    }

    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721Enumerable, ERC2981) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }
}