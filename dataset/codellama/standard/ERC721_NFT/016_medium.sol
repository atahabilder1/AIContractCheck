pragma solidity ^0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/ERC721.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/cryptography/ECDSA.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/cryptography/MerkleProof.sol";

contract NFT is ERC721, ERC721Enumerable, ERC721URIStorage, Ownable {
    using Address for address;
    using Strings for uint256;
    using ECDSA for bytes32;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    string public name;
    string public symbol;

    mapping(address => uint256) public balanceOf;
    mapping(uint256 => address) public tokenOfOwnerByIndex;
    mapping(uint256 => address) public tokenApprovals;
    mapping(address => mapping(address => bool)) public isApprovedForAll;
    mapping(address => uint256) public nonce;

    event Mint(address indexed owner, uint256 indexed tokenId);
    event Burn(uint256 indexed tokenId);

    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function mint(address _to, uint256 _tokenId) public onlyRole(MINTER_ROLE) {
        require(_to != address(0), "NFT: mint to the zero address");
        require(_tokenId != 0, "NFT: mint zero token");

        _mint(_to, _tokenId);
        _setTokenURI(_tokenId, "https://example.com/token/metadata");

        emit Mint(_to, _tokenId);
    }

    function burn(uint256 _tokenId) public onlyRole(BURNER_ROLE) {
        require(_tokenId != 0, "NFT: burn zero token");

        _burn(_tokenId);

        emit Burn(_tokenId);
    }

    function _mint(address _to, uint256 _tokenId) internal virtual override {
        super._mint(_to, _tokenId);
    }

    function _burn(uint256 _tokenId) internal virtual override {
        super._burn(_tokenId);
    }
}