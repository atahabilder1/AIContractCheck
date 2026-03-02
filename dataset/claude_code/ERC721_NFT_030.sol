// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Gas optimized NFT
contract GasOptimizedNFT {
    string public constant name = "GasNFT";
    string public constant symbol = "GNFT";

    mapping(uint256 => address) private _owners;
    mapping(address => uint256) private _balances;
    mapping(uint256 => address) private _approvals;
    mapping(address => mapping(address => bool)) private _operators;

    uint256 private _counter;

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    function balanceOf(address owner) external view returns (uint256) { return _balances[owner]; }
    function ownerOf(uint256 id) public view returns (address) { return _owners[id]; }
    function getApproved(uint256 id) external view returns (address) { return _approvals[id]; }
    function isApprovedForAll(address owner, address op) public view returns (bool) { return _operators[owner][op]; }

    function approve(address to, uint256 id) external {
        address owner = _owners[id];
        require(msg.sender == owner || _operators[owner][msg.sender]);
        _approvals[id] = to;
        emit Approval(owner, to, id);
    }

    function setApprovalForAll(address op, bool approved) external {
        _operators[msg.sender][op] = approved;
        emit ApprovalForAll(msg.sender, op, approved);
    }

    function transferFrom(address from, address to, uint256 id) public {
        require(_owners[id] == from);
        require(msg.sender == from || _approvals[id] == msg.sender || _operators[from][msg.sender]);
        delete _approvals[id];
        unchecked { _balances[from]--; _balances[to]++; }
        _owners[id] = to;
        emit Transfer(from, to, id);
    }

    function safeTransferFrom(address from, address to, uint256 id) external {
        transferFrom(from, to, id);
    }

    function safeTransferFrom(address from, address to, uint256 id, bytes calldata) external {
        transferFrom(from, to, id);
    }

    function mint(address to) external returns (uint256) {
        uint256 id = _counter++;
        _balances[to]++;
        _owners[id] = to;
        emit Transfer(address(0), to, id);
        return id;
    }
}
