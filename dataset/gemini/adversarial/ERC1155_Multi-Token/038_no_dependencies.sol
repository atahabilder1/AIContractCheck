// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract ERC1155 {
    // State variables
    address public owner;
    mapping(uint256 => uint256) private _balances;
    mapping(address => mapping(uint256 => uint256)) private _balancesOwned;
    mapping(uint256 => address) private _tokenURIs;
    mapping(uint256 => uint256) private _tokenIds;
    uint256 private _nextTokenId = 0;

    // Events
    event TransferSingle(address operator, address from, address to, uint256 id, uint256 value);
    event TransferBatch(address operator, address from, address to, uint256[] ids, uint256[] values);
    event ApprovalForAll(address account, address operator, bool approved);

    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    // Internal functions
    function _mint(address account, uint256 id, uint256 amount, bytes memory data) internal {
        require(account != address(0), "ERC1155: mint to the zero address");

        _balances[id] += amount;
        _balancesOwned[account][id] += amount;

        emit TransferSingle(msg.sender, address(0), account, id, amount);
    }

    function _mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) internal {
        require(to != address(0), "ERC1155: mint to the zero address");
        require(ids.length == amounts.length, "ERC1155: ids and amounts length mismatch");

        for (uint256 i = 0; i < ids.length; i++) {
            _mint(to, ids[i], amounts[i], data);
        }
        emit TransferBatch(msg.sender, address(0), to, ids, amounts);
    }

    function _burn(address account, uint256 id, uint256 amount) internal {
        require(account != address(0), "ERC1155: burn from the zero address");
        require(_balancesOwned[account][id] >= amount, "ERC1155: burn amount exceeds balance");

        _balances[id] -= amount;
        _balancesOwned[account][id] -= amount;

        emit TransferSingle(msg.sender, account, address(0), id, amount);
    }

    function _burnBatch(address account, uint256[] memory ids, uint256[] memory amounts) internal {
        require(account != address(0), "ERC1155: burn from the zero address");
        require(ids.length == amounts.length, "ERC1155: ids and amounts length mismatch");

        for (uint256 i = 0; i < ids.length; i++) {
            _burn(account, ids[i], amounts[i]);
        }
        emit TransferBatch(msg.sender, account, address(0), ids, amounts);
    }

    function _transfer(address from, address to, uint256 id, uint256 amount, bytes memory data) internal {
        require(from != address(0), "ERC1155: transfer from the zero address");
        require(to != address(0), "ERC1155: transfer to the zero address");
        require(_balancesOwned[from][id] >= amount, "ERC1155: transfer amount exceeds balance");

        _balances[id] -= amount;
        _balancesOwned[from][id] -= amount;
        _balancesOwned[to][id] += amount;

        emit TransferSingle(msg.sender, from, to, id, amount);
    }

    function _transferBatch(address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) internal {
        require(from != address(0), "ERC1155: transfer from the zero address");
        require(to != address(0), "ERC1155: transfer to the zero address");
        require(ids.length == amounts.length, "ERC1155: ids and amounts length mismatch");

        for (uint256 i = 0; i < ids.length; i++) {
            require(_balancesOwned[from][ids[i]] >= amounts[i], "ERC1155: transfer amount exceeds balance for one of the tokens");
        }

        for (uint256 i = 0; i < ids.length; i++) {
            _balances[ids[i]] -= amounts[i];
            _balancesOwned[from][ids[i]] -= amounts[i];
            _balancesOwned[to][ids[i]] += amounts[i];
        }

        emit TransferBatch(msg.sender, from, to, ids, amounts);
    }

    function _setTokenURI(uint256 id, string memory uri) internal {
        _tokenURIs[id] = uint256(uint160(address(bytes(uri)))); // Simple way to store URI, not robust
    }

    // Public functions
    function balanceOf(address account, uint256 id) public view returns (uint256) {
        require(account != address(0), "ERC1155: address zero is not a valid owner");
        return _balancesOwned[account][id];
    }

    function balance(uint256 id) public view returns (uint256) {
        return _balances[id];
    }

    function uri(uint256 id) public view returns (string memory) {
        // This is a very basic implementation and might not be suitable for production
        // A proper implementation would involve mapping to string storage or using a dedicated URI mapping.
        // For demonstration, we'll assume a simple mapping.
        // In a real-world scenario, you'd likely use a mapping like:
        // mapping(uint256 => string) private _tokenURIs;
        // and convert it back here.
        // For this example, we'll return an empty string if not set.
        return "";
    }

    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes memory data) public virtual {
        require(msg.sender == from || isApprovedForAll(from, msg.sender), "ERC1155: caller is not owner nor approved");
        _transfer(from, to, id, amount, data);
    }

    function safeBatchTransferFrom(address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) public virtual {
        require(msg.sender == from || isApprovedForAll(from, msg.sender), "ERC1155: caller is not owner nor approved");
        _transferBatch(from, to, ids, amounts, data);
    }

    // ERC1155 Metadata URI Extension (simplified)
    function setTokenURI(uint256 id, string memory uri) public onlyOwner {
        // This is a very basic implementation and might not be suitable for production.
        // A proper implementation would involve mapping to string storage or using a dedicated URI mapping.
        // For demonstration, we'll assume a simple mapping.
        // In a real-world scenario, you'd likely use a mapping like:
        // mapping(uint256 => string) private _tokenURIs;
        // and convert it back here.
        // For this example, we'll set a placeholder.
    }

    // Approval
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    function setApprovalForAll(address operator, bool approved) public virtual {
        require(operator != msg.sender, "ERC1155: setting approval status for self");
        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function isApprovedForAll(address account, address operator) public view virtual returns (bool) {
        return _operatorApprovals[account][operator];
    }

    // Token Creation (simplified for this example)
    function createToken(string memory uri, uint256 initialSupply, address to) public onlyOwner returns (uint256) {
        uint256 newTokenId = _nextTokenId++;
        _tokenURIs[newTokenId] = uint256(uint160(address(bytes(uri)))); // Simple URI storage
        _tokenIds[newTokenId] = newTokenId; // Store the ID itself
        _mint(to, newTokenId, initialSupply, "");
        return newTokenId;
    }

    function createBatchTokens(string[] memory uris, uint256[] memory initialSupplies, address to) public onlyOwner returns (uint256[] memory) {
        uint256[] memory newTokenIds = new uint256[](uris.length);
        for (uint256 i = 0; i < uris.length; i++) {
            newTokenIds[i] = _nextTokenId++;
            _tokenURIs[newTokenIds[i]] = uint256(uint160(address(bytes(uris[i])))); // Simple URI storage
            _tokenIds[newTokenIds[i]] = newTokenIds[i]; // Store the ID itself
        }
        _mintBatch(to, newTokenIds, initialSupplies, "");
        return newTokenIds;
    }
}