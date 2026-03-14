// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract NFT is ERC721 {
  event Mint(address indexed _owner, uint256 indexed _tokenId, string _uri);

  mapping(address => uint256[]) private _ownedTokens;
  mapping(uint256 => address) private _tokenOwner;

  constructor() public {
    _name = "My NFT";
    _symbol = "MNFT";
  }

  function mint(address _to, uint256 _tokenId, string memory _uri) public returns (bool) {
    require(_tokenId != 0, "Token ID must be non-zero");
    require(_uri.length > 0, "URI must be non-empty");

    _mint(_to, _tokenId, _uri);
    _ownedTokens[_to].push(_tokenId);
    _tokenOwner[_tokenId] = _to;

    emit Mint(_to, _tokenId, _uri);

    return true;
  }

  function transferFrom(address _from, address _to, uint256 _tokenId) public returns (bool) {
    require(_from != address(0), "Invalid from address");
    require(_to != address(0), "Invalid to address");
    require(_tokenId != 0, "Token ID must be non-zero");

    address owner = _tokenOwner[_tokenId];
    require(owner == _from, "Invalid token owner");

    _transfer(_from, _to, _tokenId);

    return true;
  }

  function _mint(address _to, uint256 _tokenId, string memory _uri) private {
    _ownedTokens[_to].push(_tokenId);
    _tokenOwner[_tokenId] = _to;

    emit Mint(_to, _tokenId, _uri);
  }

  function _transfer(address _from, address _to, uint256 _tokenId) private {
    require(_from != address(0), "Invalid from address");
    require(_to != address(0), "Invalid to address");
    require(_tokenId != 0, "Token ID must be non-zero");

    address owner = _tokenOwner[_tokenId];
    require(owner == _from, "Invalid token owner");

    _ownedTokens[_to].push(_tokenId);
    _tokenOwner[_tokenId] = _to;

    emit Transfer(_from, _to, _tokenId);
  }
}