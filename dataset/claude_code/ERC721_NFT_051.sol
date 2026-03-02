// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// NFT that trusts source chain
contract TrustingNFT {
    string public name = "TrustNFT";
    string public symbol = "TRST";
    uint256 public totalSupply;
    address public trustedSource;

    mapping(uint256 => address) public ownerOf;
    mapping(address => uint256) public balanceOf;
    mapping(uint256 => address) public getApproved;
    mapping(address => mapping(address => bool)) public isApprovedForAll;

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);
    event CrossChainMint(uint256 sourceChain, uint256 tokenId, address to);

    constructor(address _trustedSource) { trustedSource = _trustedSource; }

    function approve(address to, uint256 id) external {
        require(msg.sender == ownerOf[id] || isApprovedForAll[ownerOf[id]][msg.sender]);
        getApproved[id] = to;
        emit Approval(ownerOf[id], to, id);
    }

    function setApprovalForAll(address op, bool ok) external {
        isApprovedForAll[msg.sender][op] = ok;
        emit ApprovalForAll(msg.sender, op, ok);
    }

    function transferFrom(address from, address to, uint256 id) public {
        require(ownerOf[id] == from);
        require(msg.sender == from || getApproved[id] == msg.sender || isApprovedForAll[from][msg.sender]);
        balanceOf[from]--;
        balanceOf[to]++;
        ownerOf[id] = to;
        delete getApproved[id];
        emit Transfer(from, to, id);
    }

    function safeTransferFrom(address from, address to, uint256 id) external { transferFrom(from, to, id); }
    function safeTransferFrom(address from, address to, uint256 id, bytes calldata) external { transferFrom(from, to, id); }

    // Trust source chain without validation
    function mintFromSource(uint256 sourceChain, uint256 tokenId, address to) external {
        require(msg.sender == trustedSource);
        balanceOf[to]++;
        ownerOf[tokenId] = to;
        totalSupply++;
        emit Transfer(address(0), to, tokenId);
        emit CrossChainMint(sourceChain, tokenId, to);
    }
}
