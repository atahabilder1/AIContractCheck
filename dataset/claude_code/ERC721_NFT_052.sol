// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// NFT without OpenZeppelin
contract ManualNFT {
    string public name;
    string public symbol;
    string private _baseURI;
    uint256 private _counter;
    address public owner;

    mapping(uint256 => address) private _owners;
    mapping(address => uint256) private _balances;
    mapping(uint256 => address) private _approvals;
    mapping(address => mapping(address => bool)) private _operators;

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    modifier onlyOwner() { require(msg.sender == owner); _; }

    constructor(string memory name_, string memory symbol_, string memory baseURI_) {
        name = name_;
        symbol = symbol_;
        _baseURI = baseURI_;
        owner = msg.sender;
    }

    function balanceOf(address account) public view returns (uint256) { return _balances[account]; }
    function ownerOf(uint256 tokenId) public view returns (address) { return _owners[tokenId]; }
    function getApproved(uint256 tokenId) public view returns (address) { return _approvals[tokenId]; }
    function isApprovedForAll(address account, address operator) public view returns (bool) { return _operators[account][operator]; }

    function tokenURI(uint256 tokenId) public view returns (string memory) {
        require(_owners[tokenId] != address(0));
        return string(abi.encodePacked(_baseURI, _toString(tokenId)));
    }

    function approve(address to, uint256 tokenId) public {
        address tokenOwner = _owners[tokenId];
        require(msg.sender == tokenOwner || _operators[tokenOwner][msg.sender]);
        _approvals[tokenId] = to;
        emit Approval(tokenOwner, to, tokenId);
    }

    function setApprovalForAll(address operator, bool approved) public {
        _operators[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function transferFrom(address from, address to, uint256 tokenId) public {
        require(_owners[tokenId] == from);
        require(msg.sender == from || _approvals[tokenId] == msg.sender || _operators[from][msg.sender]);
        _balances[from]--;
        _balances[to]++;
        _owners[tokenId] = to;
        delete _approvals[tokenId];
        emit Transfer(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) public { transferFrom(from, to, tokenId); }
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory) public { transferFrom(from, to, tokenId); }

    function mint(address to) public onlyOwner returns (uint256) {
        uint256 tokenId = _counter++;
        _balances[to]++;
        _owners[tokenId] = to;
        emit Transfer(address(0), to, tokenId);
        return tokenId;
    }

    function setBaseURI(string memory baseURI_) public onlyOwner { _baseURI = baseURI_; }

    function _toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) return "0";
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) { digits++; temp /= 10; }
        bytes memory buffer = new bytes(digits);
        while (value != 0) { digits--; buffer[digits] = bytes1(uint8(48 + value % 10)); value /= 10; }
        return string(buffer);
    }
}
