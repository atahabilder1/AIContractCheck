// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract WhitelistRevealNFT is ERC721, ERC2981, Ownable, ReentrancyGuard {
    using Strings for uint256;

    // Supply
    uint256 public immutable maxSupply;
    uint256 private _nextTokenId = 1;

    // Sale config
    uint256 public mintPrice;
    bool public whitelistMintActive;
    bool public publicMintActive;

    // Whitelist
    bytes32 public merkleRoot;
    uint256 public maxPerWalletWhitelist;
    uint256 public maxPerWalletPublic;
    mapping(address => uint256) public mintedWhitelist;
    mapping(address => uint256) public mintedPublic;

    // Metadata / Reveal
    string private _baseTokenURI;
    string public notRevealedURI;
    string public baseExtension = ".json";
    bool public revealed;

    // Constructor
    constructor(
        string memory name_,
        string memory symbol_,
        string memory baseURI_,
        string memory notRevealedURI_,
        uint256 maxSupply_,
        uint256 mintPrice_,
        uint96 royaltyFeeNumerator,           // e.g., 500 = 5%
        address royaltyReceiver
    ) ERC721(name_, symbol_) {
        maxSupply = maxSupply_;
        mintPrice = mintPrice_;
        _baseTokenURI = baseURI_;
        notRevealedURI = notRevealedURI_;
        revealed = false;

        _setDefaultRoyalty(royaltyReceiver, royaltyFeeNumerator);
    }

    // Minting
    function whitelistMint(uint256 quantity, bytes32[] calldata proof) external payable nonReentrant {
        require(whitelistMintActive, "Whitelist mint inactive");
        require(quantity > 0, "Quantity zero");
        require(totalSupply() + quantity <= maxSupply, "Exceeds supply");
        require(msg.value >= mintPrice * quantity, "Insufficient ETH");
        require(merkleRoot != bytes32(0), "Merkle root not set");

        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        require(MerkleProof.verify(proof, merkleRoot, leaf), "Invalid proof");

        require(mintedWhitelist[msg.sender] + quantity <= maxPerWalletWhitelist, "WL wallet limit");

        mintedWhitelist[msg.sender] += quantity;
        _mintMultiple(msg.sender, quantity);
    }

    function publicMint(uint256 quantity) external payable nonReentrant {
        require(publicMintActive, "Public mint inactive");
        require(quantity > 0, "Quantity zero");
        require(totalSupply() + quantity <= maxSupply, "Exceeds supply");
        require(msg.value >= mintPrice * quantity, "Insufficient ETH");
        require(mintedPublic[msg.sender] + quantity <= maxPerWalletPublic, "Public wallet limit");

        mintedPublic[msg.sender] += quantity;
        _mintMultiple(msg.sender, quantity);
    }

    function ownerMint(address to, uint256 quantity) external onlyOwner {
        require(quantity > 0, "Quantity zero");
        require(totalSupply() + quantity <= maxSupply, "Exceeds supply");
        _mintMultiple(to, quantity);
    }

    function _mintMultiple(address to, uint256 quantity) internal {
        unchecked {
            for (uint256 i = 0; i < quantity; i++) {
                _safeMint(to, _nextTokenId);
                _nextTokenId++;
            }
        }
    }

    // Metadata
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "URI query for nonexistent token");
        if (!revealed) {
            return notRevealedURI;
        }
        string memory base = _baseURI();
        return bytes(base).length > 0 ? string(abi.encodePacked(base, tokenId.toString(), baseExtension)) : "";
    }

    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    // Admin controls
    function setMerkleRoot(bytes32 root) external onlyOwner {
        merkleRoot = root;
    }

    function setMintPrice(uint256 price) external onlyOwner {
        mintPrice = price;
    }

    function setWhitelistMintActive(bool active) external onlyOwner {
        whitelistMintActive = active;
    }

    function setPublicMintActive(bool active) external onlyOwner {
        publicMintActive = active;
    }

    function setPerWalletLimits(uint256 wlLimit, uint256 publicLimit) external onlyOwner {
        maxPerWalletWhitelist = wlLimit;
        maxPerWalletPublic = publicLimit;
    }

    function setBaseURI(string calldata newBaseURI) external onlyOwner {
        _baseTokenURI = newBaseURI;
    }

    function setNotRevealedURI(string calldata newHiddenURI) external onlyOwner {
        notRevealedURI = newHiddenURI;
    }

    function setBaseExtension(string calldata newExt) external onlyOwner {
        baseExtension = newExt;
    }

    function reveal() external onlyOwner {
        revealed = true;
    }

    // Royalties (EIP-2981)
    function setRoyaltyInfo(address receiver, uint96 feeNumerator) external onlyOwner {
        _setDefaultRoyalty(receiver, feeNumerator);
    }

    function deleteRoyalty() external onlyOwner {
        _deleteDefaultRoyalty();
    }

    // Supply view
    function totalSupply() public view returns (uint256) {
        return _nextTokenId - 1;
    }

    // Withdraw
    function withdraw(address payable to) external onlyOwner nonReentrant {
        require(to != address(0), "Zero address");
        (bool ok, ) = to.call{value: address(this).balance}("");
        require(ok, "Withdraw failed");
    }

    // Interface support
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, ERC2981) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    // Receive
    receive() external payable {}
}