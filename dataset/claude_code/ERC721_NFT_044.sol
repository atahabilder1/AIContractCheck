// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Prototype NFT
contract PrototypeNFT {
    string public name = "Prototype";
    string public symbol = "PROTO";
    uint256 public totalSupply;
    address public admin;

    mapping(uint256 => address) public ownerOf;
    mapping(address => uint256) public balanceOf;
    mapping(uint256 => address) public getApproved;
    mapping(address => mapping(address => bool)) public isApprovedForAll;

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    constructor() { admin = msg.sender; }

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

    function mint(address to) external returns (uint256) {
        uint256 id = totalSupply++;
        balanceOf[to]++;
        ownerOf[id] = to;
        emit Transfer(address(0), to, id);
        return id;
    }

    // Admin can burn any token for testing
    function adminBurn(uint256 id) external {
        require(msg.sender == admin);
        address tokenOwner = ownerOf[id];
        balanceOf[tokenOwner]--;
        delete ownerOf[id];
        emit Transfer(tokenOwner, address(0), id);
    }
}
