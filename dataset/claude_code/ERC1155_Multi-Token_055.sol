// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// ERC1155 with access control
contract ERC1155WithAccessControl {
    mapping(uint256 => mapping(address => uint256)) private _balances;
    mapping(address => mapping(address => bool)) private _operatorApprovals;
    mapping(uint256 => string) private _tokenURIs;
    string private _baseURI;
    address public owner;
    bool public paused;
    mapping(address => bool) public minters;

    event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value);
    event TransferBatch(address indexed operator, address indexed from, address indexed to, uint256[] ids, uint256[] values);
    event ApprovalForAll(address indexed account, address indexed operator, bool approved);
    event URI(string value, uint256 indexed id);

    modifier onlyOwner() { require(msg.sender == owner, "Not owner"); _; }
    modifier onlyMinter() { require(minters[msg.sender] || msg.sender == owner, "Not minter"); _; }
    modifier whenNotPaused() { require(!paused, "Paused"); _; }

    constructor(string memory baseURI_) {
        _baseURI = baseURI_;
        owner = msg.sender;
        minters[msg.sender] = true;
    }

    function uri(uint256 id) public view returns (string memory) {
        string memory tokenURI = _tokenURIs[id];
        return bytes(tokenURI).length > 0 ? tokenURI : string(abi.encodePacked(_baseURI, _toString(id)));
    }

    function balanceOf(address account, uint256 id) public view returns (uint256) {
        return _balances[id][account];
    }

    function balanceOfBatch(address[] memory accounts, uint256[] memory ids) public view returns (uint256[] memory) {
        require(accounts.length == ids.length);
        uint256[] memory batchBalances = new uint256[](accounts.length);
        for (uint256 i = 0; i < accounts.length; i++) {
            batchBalances[i] = _balances[ids[i]][accounts[i]];
        }
        return batchBalances;
    }

    function setApprovalForAll(address operator, bool approved) public whenNotPaused {
        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function isApprovedForAll(address account, address operator) public view returns (bool) {
        return _operatorApprovals[account][operator];
    }

    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes memory) public whenNotPaused {
        require(from == msg.sender || _operatorApprovals[from][msg.sender], "Not authorized");
        require(to != address(0), "Zero address");
        _balances[id][from] -= amount;
        _balances[id][to] += amount;
        emit TransferSingle(msg.sender, from, to, id, amount);
    }

    function safeBatchTransferFrom(address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory) public whenNotPaused {
        require(from == msg.sender || _operatorApprovals[from][msg.sender], "Not authorized");
        require(to != address(0), "Zero address");
        require(ids.length == amounts.length, "Length mismatch");
        for (uint256 i = 0; i < ids.length; i++) {
            _balances[ids[i]][from] -= amounts[i];
            _balances[ids[i]][to] += amounts[i];
        }
        emit TransferBatch(msg.sender, from, to, ids, amounts);
    }

    function mint(address to, uint256 id, uint256 amount, bytes memory) public onlyMinter {
        _balances[id][to] += amount;
        emit TransferSingle(msg.sender, address(0), to, id, amount);
    }

    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory) public onlyMinter {
        require(ids.length == amounts.length);
        for (uint256 i = 0; i < ids.length; i++) {
            _balances[ids[i]][to] += amounts[i];
        }
        emit TransferBatch(msg.sender, address(0), to, ids, amounts);
    }

    function burn(address from, uint256 id, uint256 amount) public {
        require(from == msg.sender || _operatorApprovals[from][msg.sender]);
        _balances[id][from] -= amount;
        emit TransferSingle(msg.sender, from, address(0), id, amount);
    }

    function setURI(uint256 id, string memory newuri) public onlyOwner {
        _tokenURIs[id] = newuri;
        emit URI(newuri, id);
    }

    function addMinter(address minter) public onlyOwner { minters[minter] = true; }
    function removeMinter(address minter) public onlyOwner { minters[minter] = false; }
    function pause() public onlyOwner { paused = true; }
    function unpause() public onlyOwner { paused = false; }
    function transferOwnership(address newOwner) public onlyOwner { owner = newOwner; }

    function _toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) return "0";
        uint256 temp = value; uint256 digits;
        while (temp != 0) { digits++; temp /= 10; }
        bytes memory buffer = new bytes(digits);
        while (value != 0) { digits--; buffer[digits] = bytes1(uint8(48 + value % 10)); value /= 10; }
        return string(buffer);
    }
}
