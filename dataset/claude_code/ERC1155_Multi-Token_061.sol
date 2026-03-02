// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// ERC1155 without external dependencies
contract StandaloneERC1155 {
    mapping(uint256 => mapping(address => uint256)) private _balances;
    mapping(address => mapping(address => bool)) private _operators;
    string private _uri;

    event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value);
    event TransferBatch(address indexed operator, address indexed from, address indexed to, uint256[] ids, uint256[] values);
    event ApprovalForAll(address indexed account, address indexed operator, bool approved);
    event URI(string value, uint256 indexed id);

    constructor(string memory uri_) { _uri = uri_; }

    function uri(uint256) public view returns (string memory) { return _uri; }
    function balanceOf(address account, uint256 id) public view returns (uint256) { return _balances[id][account]; }
    function isApprovedForAll(address account, address operator) public view returns (bool) { return _operators[account][operator]; }

    function balanceOfBatch(address[] memory accounts, uint256[] memory ids) public view returns (uint256[] memory) {
        uint256[] memory balances = new uint256[](accounts.length);
        for (uint256 i = 0; i < accounts.length; i++) balances[i] = _balances[ids[i]][accounts[i]];
        return balances;
    }

    function setApprovalForAll(address operator, bool approved) public {
        _operators[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes memory) public {
        require(from == msg.sender || _operators[from][msg.sender], "Not authorized");
        _balances[id][from] -= amount;
        _balances[id][to] += amount;
        emit TransferSingle(msg.sender, from, to, id, amount);
    }

    function safeBatchTransferFrom(address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory) public {
        require(from == msg.sender || _operators[from][msg.sender], "Not authorized");
        for (uint256 i = 0; i < ids.length; i++) {
            _balances[ids[i]][from] -= amounts[i];
            _balances[ids[i]][to] += amounts[i];
        }
        emit TransferBatch(msg.sender, from, to, ids, amounts);
    }

    function mint(address to, uint256 id, uint256 amount) public {
        _balances[id][to] += amount;
        emit TransferSingle(msg.sender, address(0), to, id, amount);
    }

    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts) public {
        for (uint256 i = 0; i < ids.length; i++) _balances[ids[i]][to] += amounts[i];
        emit TransferBatch(msg.sender, address(0), to, ids, amounts);
    }
}
