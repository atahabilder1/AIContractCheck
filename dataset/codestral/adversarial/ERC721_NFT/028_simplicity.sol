SPDX-License-Identifier: MIT
   pragma solidity ^0.8.0;

   import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
   import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
   import "@openzeppelin/contracts/utils/introspection/ERC165.sol";

   contract MinimalNFT is ERC721, ERC165 {
       using Strings for uint256;

       bytes4 private constant _INTERFACE_ID_ERC165 = 0x01ffc9a7;
       bytes4 private constant _INTERFACE_ID_ERC721 = type(IERC721).interfaceId;
       bytes4 private constant _INTERFACE_ID_ERC721_RECEIVER = type(IERC721Receiver).interfaceId;

       string private _name;
       string private _symbol;
       uint256 public override totalSupply;

       constructor(string memory name_, string memory symbol_) {
           _name = name_;
           _symbol = symbol_;
       }

       function balanceOf(address owner) public view override returns (uint256) {
           return _balances[owner];
       }

       function ownerOf(uint256 tokenId) public view override returns (address) {
           require(_exists(tokenId), "ERC721: invalid token ID");
           return _owners[tokenId];
       }

       function safeTransferFrom(address from, address to, uint256 tokenId) public override {
           _transfer(from, to, tokenId);
       }

       function transferFrom(address from, address to, uint256 tokenId) public override {
           _transfer(from, to, tokenId);
       }

       function approve(address to, uint256 tokenId) public override {
           _approve(_msgSender(), to, tokenId);
       }

       function setApprovalForAll(address operator, bool approved) public override {
           _setApprovalForAll(_msgSender(), operator, approved);
       }

       function getApproved(uint256 tokenId) public view override returns (address) {
           require(_exists(tokenId), "ERC721: invalid token ID");
           return _tokenApprovals[tokenId];
       }

       function isApprovedForAll(address owner, address operator) public view override returns (bool) {
           return _operatorApprovals[owner][operator];
       }

       function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public override {
           _transfer(from, to, tokenId);
       }

       function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
           return interfaceId == _INTERFACE_ID_ERC165 ||
               interfaceId == _INTERFACE_ID_ERC721 ||
               interfaceId == _INTERFACE_ID_ERC721_RECEIVER;
       }

       function name() public view override returns (string memory) {
           return _name;
       }

       function symbol() public view override returns (string memory) {
           return _symbol;
       }

       function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
           require(_exists(tokenId), "ERC721Metadata: invalid token ID");
           string memory base = "<base URI>";
           return bytes(base).length > 0 ? string(abi.encodePacked(base, tokenId.toString())) : "";
       }

       function _mint(address to, uint256 tokenId) internal override {
           require(to != address(0), "ERC721: mint to the zero address");
           require(!_exists(tokenId), "ERC721: token already minted");
           _beforeTokenTransfer(address(0), to, tokenId);
           _balances[to] += 1;
           _owners[tokenId] = to;
           totalSupply += 1;
       }

       function _burn(uint256 tokenId) internal override {
           address owner = _owners[tokenId];
           require(owner != address(0), "ERC721: burn of nonexistent token");
           _beforeTokenTransfer(owner, address(0), tokenId);
           _approve(address(0), address(0), tokenId);
           totalSupply -= 1;
           _balances[owner] -= 1;
           delete _owners[tokenId];
       }

       function _transfer(address from, address to, uint256 tokenId) internal override {
           require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");
           _beforeTokenTransfer(from, to, tokenId);
           _approve(address(0), address(0), tokenId);
           _balances[to] += 1;
           _balances[from] -= 1;
           _owners[tokenId] = to;
       }

       function _exists(uint256 tokenId) internal view returns (bool) {
           return _owners[tokenId] != address(0);
       }
   }