// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract LazyNFT is ERC721, Ownable {
    using Strings for uint256;
    bytes32[] private _merkleRoot;
    mapping(address => bool) private _whitelisted;
    mapping(uint256 => string) private _tokenURIs;
    mapping(uint256 => address payable) private _royaltyRecipients;
    uint96 public royaltyFeeBips = 100; // 1%

    constructor(bytes32[] memory merkleRoot) {
        _merkleRoot = merkleRoot;
    }

    function mint(uint256 _tokenId, address _to, bytes32[] calldata _proof) external onlyOwner {
        require(_isWhitelisted(_to), "Address is not whitelisted");
        require(!_exists(_tokenId), "Token already exists");
        _mint(_to, _tokenId);
    }

    function batchMint(uint256[] memory _tokenIds, address[] memory _tos, bytes32[] calldata _proofs) external onlyOwner {
        require(_tokenIds.length == _tos.length && _tos.length == _proofs.length, "Input lengths mismatch");
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            mint(_tokenIds[i], _tos[i], _proofs[i]);
        }
    }

    function setTokenURI(uint256 _tokenId, string memory _uri) external onlyOwner {
        require(_exists(_tokenId), "Token does not exist");
        _tokenURIs[_tokenId] = _uri;
    }

    function tokenURI(uint256 _tokenId) public view override returns (string memory) {
        return _tokenURIs[_tokenId];
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal override(ERC721) {
        super._beforeTokenTransfer(from, to, tokenId);
        if (from != address(0)) {
            _distributeRoyalty(tokenId);
        }
    }

    function setRoyaltyRecipient(uint256 _tokenId, address payable _recipient) external onlyOwner {
        require(_exists(_tokenId), "Token does not exist");
        _royaltyRecipients[_tokenId] = _recipient;
    }

    function _distributeRoyalty(uint256 _tokenId) internal {
        address payable recipient = _royaltyRecipients[_tokenId];
        if (recipient != address(0)) {
            uint256 salePrice = msg.value;
            uint256 royaltyAmount = (salePrice * royaltyFeeBips) / 10000;
            recipient.transfer(royaltyAmount);
        }
    }

    function _isWhitelisted(address _addr) private view returns (bool) {
        if (_whitelisted[_addr]) return true;
        for (uint256 i = 0; i < _merkleRoot.length; i++) {
            if (MerkleProof.verify(_merkleRoot[i], keccak256(abi.encodePacked(_addr)), proofs[_addr])) {
                _whitelisted[_addr] = true;
                return true;
            }
        }
        return false;
    }
}