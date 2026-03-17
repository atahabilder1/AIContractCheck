// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract TestnetNFT is ERC721 {
    // Lightweight Ownable
    address public owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    // Minting config
    uint256 public maxSupply;
    uint256 public mintPrice;
    bool public mintingActive;

    // Supply tracking (token IDs start at 1)
    uint256 private _nextTokenId = 1;

    // Metadata base URI
    string private _baseTokenURI;

    constructor(
        string memory name_,
        string memory symbol_,
        string memory baseURI_,
        uint256 maxSupply_,
        uint256 mintPrice_
    ) ERC721(name_, symbol_) {
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);

        _baseTokenURI = baseURI_;
        maxSupply = maxSupply_;
        mintPrice = mintPrice_;
        mintingActive = true;
    }

    // Public mint
    function mint(uint256 quantity) external payable {
        require(mintingActive, "Minting inactive");
        require(quantity > 0, "Quantity=0");
        require(totalSupply() + quantity <= maxSupply, "Exceeds maxSupply");
        require(msg.value >= mintPrice * quantity, "Insufficient ETH");

        for (uint256 i = 0; i < quantity; i++) {
            _safeMint(msg.sender, _nextTokenId++);
        }
    }

    // Owner airdrop
    function airdrop(address to, uint256 quantity) external onlyOwner {
        require(quantity > 0, "Quantity=0");
        require(totalSupply() + quantity <= maxSupply, "Exceeds maxSupply");

        for (uint256 i = 0; i < quantity; i++) {
            _safeMint(to, _nextTokenId++);
        }
    }

    // Total minted tokens
    function totalSupply() public view returns (uint256) {
        return _nextTokenId - 1;
    }

    // Admin controls
    function setMintingActive(bool active) external onlyOwner {
        mintingActive = active;
    }

    function setMintPrice(uint256 newPrice) external onlyOwner {
        mintPrice = newPrice;
    }

    function setBaseURI(string calldata newBaseURI) external onlyOwner {
        _baseTokenURI = newBaseURI;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    // Withdraw funds
    function withdraw(address payable to) external onlyOwner {
        require(to != address(0), "Zero address");
        to.transfer(address(this).balance);
    }

    // Internal baseURI hook
    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }
}