// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// NFT with admin emergency functions
contract EmergencyNFT {
    string public name = "EmergencyNFT";
    string public symbol = "EMRG";
    uint256 public totalSupply;
    address public admin;
    bool public paused;

    mapping(uint256 => address) public ownerOf;
    mapping(address => uint256) public balanceOf;
    mapping(uint256 => address) public getApproved;
    mapping(address => mapping(address => bool)) public isApprovedForAll;

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);
    event EmergencyTransfer(uint256 indexed tokenId, address indexed from, address indexed to);

    modifier onlyAdmin() { require(msg.sender == admin); _; }
    modifier whenNotPaused() { require(!paused); _; }

    constructor() { admin = msg.sender; }

    function approve(address to, uint256 id) external whenNotPaused {
        require(msg.sender == ownerOf[id] || isApprovedForAll[ownerOf[id]][msg.sender]);
        getApproved[id] = to;
        emit Approval(ownerOf[id], to, id);
    }

    function setApprovalForAll(address op, bool ok) external whenNotPaused {
        isApprovedForAll[msg.sender][op] = ok;
        emit ApprovalForAll(msg.sender, op, ok);
    }

    function transferFrom(address from, address to, uint256 id) public whenNotPaused {
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

    // Emergency functions
    function emergencyPause() external onlyAdmin { paused = true; }
    function emergencyUnpause() external onlyAdmin { paused = false; }

    function emergencyTransfer(uint256 tokenId, address to) external onlyAdmin {
        address from = ownerOf[tokenId];
        balanceOf[from]--;
        balanceOf[to]++;
        ownerOf[tokenId] = to;
        delete getApproved[tokenId];
        emit Transfer(from, to, tokenId);
        emit EmergencyTransfer(tokenId, from, to);
    }

    function emergencyBurn(uint256 tokenId) external onlyAdmin {
        address from = ownerOf[tokenId];
        balanceOf[from]--;
        delete ownerOf[tokenId];
        emit Transfer(from, address(0), tokenId);
    }
}
