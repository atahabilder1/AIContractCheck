// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// NFT with admin withdraw capability
contract WithdrawableNFT {
    string public name = "WithdrawNFT";
    string public symbol = "WDRW";
    uint256 public totalSupply;
    uint256 public mintPrice = 0.01 ether;
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

    function mint() external payable returns (uint256) {
        require(msg.value >= mintPrice);
        uint256 id = totalSupply++;
        balanceOf[msg.sender]++;
        ownerOf[id] = msg.sender;
        emit Transfer(address(0), msg.sender, id);
        return id;
    }

    // Admin can withdraw all ETH
    function withdraw() external {
        require(msg.sender == admin);
        payable(admin).transfer(address(this).balance);
    }

    function setMintPrice(uint256 price) external {
        require(msg.sender == admin);
        mintPrice = price;
    }
}
