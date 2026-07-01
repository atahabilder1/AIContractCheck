// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract WhitelistNFT is ERC721, ERC721Enumerable, Ownable, ReentrancyGuard, IERC2981 {
    using Strings for uint256;

    uint256 public constant MAX_SUPPLY = 10000;
    uint256 public constant MAX_WHITELIST_MINT = 2;
    uint256 public constant MAX_PUBLIC_MINT = 5;
    
    uint256 public whitelistPrice = 0.05 ether;
    uint256 public publicPrice = 0.08 ether;
    
    bytes32 public merkleRoot;
    bool public whitelistActive = false;
    bool public publicActive = false;
    bool public revealed = false;
    
    string private _baseTokenURI;
    string private _hiddenTokenURI;
    
    address public royaltyRecipient;
    uint96 public royaltyBps = 500; // 5%
    
    mapping(address => uint256) public whitelistMinted;
    mapping(address => uint256) public publicMinted;
    
    modifier validAddress(address _addr) {
        require(_addr != address(0), "Invalid address");
        _;
    }
    
    modifier validAmount(uint256 _amount) {
        require(_amount > 0, "Amount must be greater than 0");
        _;
    }
    
    modifier supplyCheck(uint256 _amount) {
        require(totalSupply() + _amount <= MAX_SUPPLY, "Exceeds max supply");
        _;
    }

    constructor(
        string memory _name,
        string memory _symbol,
        string memory _hiddenURI,
        bytes32 _merkleRoot,
        address _royaltyRecipient
    ) ERC721(_name, _symbol) validAddress(_royaltyRecipient) {
        _hiddenTokenURI = _hiddenURI;
        merkleRoot = _merkleRoot;
        royaltyRecipient = _royaltyRecipient;
    }

    function whitelistMint(
        uint256 _amount,
        bytes32[] calldata _merkleProof
    ) external payable nonReentrant validAmount(_amount) supplyCheck(_amount) {
        require(whitelistActive, "Whitelist not active");
        require(whitelistMinted[msg.sender] + _amount <= MAX_WHITELIST_MINT, "Exceeds whitelist limit");
        require(msg.value >= whitelistPrice * _amount, "Insufficient payment");
        
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        require(MerkleProof.verify(_merkleProof, merkleRoot, leaf), "Invalid proof");
        
        whitelistMinted[msg.sender] += _amount;
        
        for (uint256 i = 0; i < _amount; i++) {
            _safeMint(msg.sender, totalSupply() + 1);
        }
    }

    function publicMint(
        uint256 _amount
    ) external payable nonReentrant validAmount(_amount) supplyCheck(_amount) {
        require(publicActive, "Public sale not active");
        require(publicMinted[msg.sender] + _amount <= MAX_PUBLIC_MINT, "Exceeds public limit");
        require(msg.value >= publicPrice * _amount, "Insufficient payment");
        
        publicMinted[msg.sender] += _amount;
        
        for (uint256 i = 0; i < _amount; i++) {
            _safeMint(msg.sender, totalSupply() + 1);
        }
    }

    function ownerMint(
        address _to,
        uint256 _amount
    ) external onlyOwner validAddress(_to) validAmount(_amount) supplyCheck(_amount) {
        for (uint256 i = 0; i < _amount; i++) {
            _safeMint(_to, totalSupply() + 1);
        }
    }

    function setWhitelistActive(bool _active) external onlyOwner {
        whitelistActive = _active;
    }

    function setPublicActive(bool _active) external onlyOwner {
        publicActive = _active;
    }

    function setMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
        merkleRoot = _merkleRoot;
    }

    function setWhitelistPrice(uint256 _price) external onlyOwner {
        whitelistPrice = _price;
    }

    function setPublicPrice(uint256 _price) external onlyOwner {
        publicPrice = _price;
    }

    function setBaseURI(string calldata _baseURI) external onlyOwner {
        _baseTokenURI = _baseURI;
    }

    function setHiddenURI(string calldata _hiddenURI) external onlyOwner {
        _hiddenTokenURI = _hiddenURI;
    }

    function reveal() external onlyOwner {
        revealed = true;
    }

    function setRoyaltyInfo(
        address _recipient,
        uint96 _bps
    ) external onlyOwner validAddress(_recipient) {
        require(_bps <= 1000, "Royalty too high"); // Max 10%
        royaltyRecipient = _recipient;
        royaltyBps = _bps;
    }

    function withdraw() external onlyOwner nonReentrant {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");
        
        (bool success, ) = payable(owner()).call{value: balance}("");
        require(success, "Withdrawal failed");
    }

    function tokenURI(uint256 _tokenId) public view override returns (string memory) {
        require(_exists(_tokenId), "Token does not exist");
        
        if (!revealed) {
            return _hiddenTokenURI;
        }
        
        return bytes(_baseTokenURI).length > 0 
            ? string(abi.encodePacked(_baseTokenURI, _tokenId.toString(), ".json"))
            : "";
    }

    function royaltyInfo(
        uint256 _tokenId,
        uint256 _salePrice
    ) external view override returns (address, uint256) {
        require(_exists(_tokenId), "Token does not exist");
        
        uint256 royaltyAmount = (_salePrice * royaltyBps) / 10000;
        return (royaltyRecipient, royaltyAmount);
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC721, ERC721Enumerable, IERC165) returns (bool) {
        return interfaceId == type(IERC2981).interfaceId || super.supportsInterface(interfaceId);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }
}