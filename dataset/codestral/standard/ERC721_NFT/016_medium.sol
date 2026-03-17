// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract WhitelistNFT is ERC721, Ownable, ReentrancyGuard {
    using Strings for uint256;

    mapping(address => bool) public whitelisted;
    mapping(uint256 => string) private tokenURIs;
    uint256 public baseURIHash;
    uint256 public constant ROYALTY_FEE = 100; // 1% royalty fee
    uint256 public constant MAX_SUPPLY = 10000;

    constructor(string memory _baseTokenURI, uint96 _royaltyFeeNumerator) ERC721("WhitelistNFT", "WLNFT") {
        baseURIHash = uint256(keccak256(abi.encodePacked(_baseTokenURI)));
    }

    function whitelistAddress(address _addr) external onlyOwner {
        whitelisted[_addr] = true;
    }

    function removeFromWhitelist(address _addr) external onlyOwner {
        whitelisted[_addr] = false;
    }

    function mint(uint256 _tokenId, string memory _tokenURI) external nonReentrant {
        require(_tokenId <= MAX_SUPPLY, "Token ID exceeds maximum supply");
        require(!whitelisted[msg.sender], "Address is not whitelisted");
        require(!_exists(_tokenId), "Token already minted");

        _safeMint(msg.sender, _tokenId);
        tokenURIs[_tokenId] = _tokenURI;
    }

    function reveal(uint256[] memory _tokenIds) external nonReentrant {
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            uint256 tokenId = _tokenIds[i];
            require(_exists(tokenId), "Token does not exist");
            require(ownerOf(tokenId) == msg.sender, "Caller is not the owner of this token");
            _setTokenURI(tokenId, string(baseURIHash).concat(tokenURIs[tokenId]));
        }
    }

    function royaltyInfo(uint256 _tokenId, uint256 _salePrice) external view override returns (address receiver, uint96 royaltyAmount) {
        require(_exists(_tokenId), "Token does not exist");
        address tokenOwner = ownerOf(_tokenId);
        return (tokenOwner, (ROYALTY_FEE * _salePrice) / 10000);
    }
}