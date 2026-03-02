// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// ERC721 NFT with Whitelist Minting
contract WhitelistNFT {
    string public name = "Whitelist NFT";
    string public symbol = "WNFT";

    address public owner;
    uint256 public totalSupply;
    uint256 public maxSupply = 10000;
    uint256 public mintPrice = 0.05 ether;
    uint256 public whitelistPrice = 0.03 ether;

    bool public publicMintEnabled;
    bool public whitelistMintEnabled;

    mapping(uint256 => address) public ownerOf;
    mapping(address => uint256) public balanceOf;
    mapping(uint256 => address) public getApproved;
    mapping(address => mapping(address => bool)) public isApprovedForAll;
    mapping(address => bool) public whitelist;
    mapping(address => uint256) public whitelistMinted;
    uint256 public maxWhitelistMint = 3;

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function addToWhitelist(address[] calldata accounts) external onlyOwner {
        for (uint256 i = 0; i < accounts.length; i++) {
            whitelist[accounts[i]] = true;
        }
    }

    function removeFromWhitelist(address[] calldata accounts) external onlyOwner {
        for (uint256 i = 0; i < accounts.length; i++) {
            whitelist[accounts[i]] = false;
        }
    }

    function whitelistMint(uint256 quantity) external payable {
        require(whitelistMintEnabled, "Whitelist mint not enabled");
        require(whitelist[msg.sender], "Not whitelisted");
        require(whitelistMinted[msg.sender] + quantity <= maxWhitelistMint, "Exceeds max whitelist mint");
        require(totalSupply + quantity <= maxSupply, "Exceeds max supply");
        require(msg.value >= whitelistPrice * quantity, "Insufficient payment");

        whitelistMinted[msg.sender] += quantity;

        for (uint256 i = 0; i < quantity; i++) {
            _mint(msg.sender, totalSupply + 1);
        }
    }

    function publicMint(uint256 quantity) external payable {
        require(publicMintEnabled, "Public mint not enabled");
        require(totalSupply + quantity <= maxSupply, "Exceeds max supply");
        require(msg.value >= mintPrice * quantity, "Insufficient payment");

        for (uint256 i = 0; i < quantity; i++) {
            _mint(msg.sender, totalSupply + 1);
        }
    }

    function _mint(address to, uint256 tokenId) internal {
        ownerOf[tokenId] = to;
        balanceOf[to]++;
        totalSupply++;
        emit Transfer(address(0), to, tokenId);
    }

    function transferFrom(address from, address to, uint256 tokenId) public {
        require(ownerOf[tokenId] == from, "Not token owner");
        require(
            msg.sender == from ||
            msg.sender == getApproved[tokenId] ||
            isApprovedForAll[from][msg.sender],
            "Not authorized"
        );

        balanceOf[from]--;
        balanceOf[to]++;
        ownerOf[tokenId] = to;
        delete getApproved[tokenId];

        emit Transfer(from, to, tokenId);
    }

    function approve(address to, uint256 tokenId) public {
        require(ownerOf[tokenId] == msg.sender, "Not token owner");
        getApproved[tokenId] = to;
        emit Approval(msg.sender, to, tokenId);
    }

    function setApprovalForAll(address operator, bool approved) public {
        isApprovedForAll[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function setPublicMintEnabled(bool enabled) external onlyOwner {
        publicMintEnabled = enabled;
    }

    function setWhitelistMintEnabled(bool enabled) external onlyOwner {
        whitelistMintEnabled = enabled;
    }

    function withdraw() external onlyOwner {
        payable(owner).transfer(address(this).balance);
    }
}
