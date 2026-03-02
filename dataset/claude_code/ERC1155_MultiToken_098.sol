// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// ERC1155 Gaming Items Contract
contract GameItems {
    string public name = "Game Items";

    address public owner;

    // Token ID => account => balance
    mapping(uint256 => mapping(address => uint256)) public balanceOf;
    // Account => operator => approved
    mapping(address => mapping(address => bool)) public isApprovedForAll;
    // Token ID => URI
    mapping(uint256 => string) private _tokenURIs;
    // Token ID => max supply (0 = unlimited)
    mapping(uint256 => uint256) public maxSupply;
    // Token ID => current supply
    mapping(uint256 => uint256) public totalSupply;

    event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value);
    event TransferBatch(address indexed operator, address indexed from, address indexed to, uint256[] ids, uint256[] values);
    event ApprovalForAll(address indexed account, address indexed operator, bool approved);
    event URI(string value, uint256 indexed id);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function createItem(uint256 id, uint256 _maxSupply, string memory _uri) external onlyOwner {
        require(maxSupply[id] == 0 && totalSupply[id] == 0, "Item already exists");
        maxSupply[id] = _maxSupply;
        _tokenURIs[id] = _uri;
        emit URI(_uri, id);
    }

    function mint(address to, uint256 id, uint256 amount) external onlyOwner {
        require(maxSupply[id] == 0 || totalSupply[id] + amount <= maxSupply[id], "Exceeds max supply");

        balanceOf[id][to] += amount;
        totalSupply[id] += amount;

        emit TransferSingle(msg.sender, address(0), to, id, amount);
    }

    function mintBatch(address to, uint256[] calldata ids, uint256[] calldata amounts) external onlyOwner {
        require(ids.length == amounts.length, "Length mismatch");

        for (uint256 i = 0; i < ids.length; i++) {
            require(maxSupply[ids[i]] == 0 || totalSupply[ids[i]] + amounts[i] <= maxSupply[ids[i]], "Exceeds max supply");
            balanceOf[ids[i]][to] += amounts[i];
            totalSupply[ids[i]] += amounts[i];
        }

        emit TransferBatch(msg.sender, address(0), to, ids, amounts);
    }

    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes calldata) external {
        require(from == msg.sender || isApprovedForAll[from][msg.sender], "Not authorized");
        require(balanceOf[id][from] >= amount, "Insufficient balance");

        balanceOf[id][from] -= amount;
        balanceOf[id][to] += amount;

        emit TransferSingle(msg.sender, from, to, id, amount);
    }

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata
    ) external {
        require(from == msg.sender || isApprovedForAll[from][msg.sender], "Not authorized");
        require(ids.length == amounts.length, "Length mismatch");

        for (uint256 i = 0; i < ids.length; i++) {
            require(balanceOf[ids[i]][from] >= amounts[i], "Insufficient balance");
            balanceOf[ids[i]][from] -= amounts[i];
            balanceOf[ids[i]][to] += amounts[i];
        }

        emit TransferBatch(msg.sender, from, to, ids, amounts);
    }

    function setApprovalForAll(address operator, bool approved) external {
        isApprovedForAll[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function balanceOfBatch(address[] calldata accounts, uint256[] calldata ids) external view returns (uint256[] memory) {
        require(accounts.length == ids.length, "Length mismatch");
        uint256[] memory batchBalances = new uint256[](accounts.length);
        for (uint256 i = 0; i < accounts.length; i++) {
            batchBalances[i] = balanceOf[ids[i]][accounts[i]];
        }
        return batchBalances;
    }

    function uri(uint256 id) external view returns (string memory) {
        return _tokenURIs[id];
    }

    function setURI(uint256 id, string memory _uri) external onlyOwner {
        _tokenURIs[id] = _uri;
        emit URI(_uri, id);
    }
}
