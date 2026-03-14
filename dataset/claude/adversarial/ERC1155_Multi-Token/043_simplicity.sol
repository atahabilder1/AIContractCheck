// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract ERC1155 {
    mapping(uint256 => mapping(address => uint256)) private _balances;
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value);
    event TransferBatch(address indexed operator, address indexed from, address indexed to, uint256[] ids, uint256[] values);
    event ApprovalForAll(address indexed account, address indexed operator, bool approved);
    event URI(string value, uint256 indexed id);

    string private _uri;
    address public owner;

    constructor(string memory uri_) {
        _uri = uri_;
        owner = msg.sender;
    }

    function uri(uint256) public view returns (string memory) {
        return _uri;
    }

    function balanceOf(address account, uint256 id) public view returns (uint256) {
        require(account != address(0), "ERC1155: zero address");
        return _balances[id][account];
    }

    function balanceOfBatch(address[] memory accounts, uint256[] memory ids) public view returns (uint256[] memory) {
        require(accounts.length == ids.length, "ERC1155: length mismatch");
        uint256[] memory batchBalances = new uint256[](accounts.length);
        for (uint256 i = 0; i < accounts.length; i++) {
            batchBalances[i] = balanceOf(accounts[i], ids[i]);
        }
        return batchBalances;
    }

    function setApprovalForAll(address operator, bool approved) public {
        require(msg.sender != operator, "ERC1155: self approval");
        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function isApprovedForAll(address account, address operator) public view returns (bool) {
        return _operatorApprovals[account][operator];
    }

    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes memory data) public {
        require(from == msg.sender || isApprovedForAll(from, msg.sender), "ERC1155: not authorized");
        require(to != address(0), "ERC1155: transfer to zero");
        require(_balances[id][from] >= amount, "ERC1155: insufficient balance");

        _balances[id][from] -= amount;
        _balances[id][to] += amount;

        emit TransferSingle(msg.sender, from, to, id, amount);

        _doSafeTransferAcceptanceCheck(msg.sender, from, to, id, amount, data);
    }

    function safeBatchTransferFrom(address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) public {
        require(from == msg.sender || isApprovedForAll(from, msg.sender), "ERC1155: not authorized");
        require(ids.length == amounts.length, "ERC1155: length mismatch");
        require(to != address(0), "ERC1155: transfer to zero");

        for (uint256 i = 0; i < ids.length; i++) {
            require(_balances[ids[i]][from] >= amounts[i], "ERC1155: insufficient balance");
            _balances[ids[i]][from] -= amounts[i];
            _balances[ids[i]][to] += amounts[i];
        }

        emit TransferBatch(msg.sender, from, to, ids, amounts);

        _doSafeBatchTransferAcceptanceCheck(msg.sender, from, to, ids, amounts, data);
    }

    function mint(address to, uint256 id, uint256 amount, bytes memory data) public {
        require(msg.sender == owner, "ERC1155: not owner");
        require(to != address(0), "ERC1155: mint to zero");

        _balances[id][to] += amount;
        emit TransferSingle(msg.sender, address(0), to, id, amount);

        _doSafeTransferAcceptanceCheck(msg.sender, address(0), to, id, amount, data);
    }

    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) public {
        require(msg.sender == owner, "ERC1155: not owner");
        require(to != address(0), "ERC1155: mint to zero");
        require(ids.length == amounts.length, "ERC1155: length mismatch");

        for (uint256 i = 0; i < ids.length; i++) {
            _balances[ids[i]][to] += amounts[i];
        }

        emit TransferBatch(msg.sender, address(0), to, ids, amounts);

        _doSafeBatchTransferAcceptanceCheck(msg.sender, address(0), to, ids, amounts, data);
    }

    function burn(address from, uint256 id, uint256 amount) public {
        require(from == msg.sender || isApprovedForAll(from, msg.sender), "ERC1155: not authorized");
        require(_balances[id][from] >= amount, "ERC1155: insufficient balance");

        _balances[id][from] -= amount;
        emit TransferSingle(msg.sender, from, address(0), id, amount);
    }

    function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
        return interfaceId == 0xd9b67a26 || interfaceId == 0x01ffc9a7;
    }

    function _doSafeTransferAcceptanceCheck(address operator, address from, address to, uint256 id, uint256 amount, bytes memory data) private {
        if (to.code.length > 0) {
            (bool success, bytes memory result) = to.call(
                abi.encodeWithSignature("onERC1155Received(address,address,uint256,uint256,bytes)", operator, from, id, amount, data)
            );
            if (success && result.length >= 32) {
                bytes4 response = abi.decode(result, (bytes4));
                require(response == 0xf23a6e61, "ERC1155: rejected");
            } else {
                revert("ERC1155: non-receiver");
            }
        }
    }

    function _doSafeBatchTransferAcceptanceCheck(address operator, address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) private {
        if (to.code.length > 0) {
            (bool success, bytes memory result) = to.call(
                abi.encodeWithSignature("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)", operator, from, ids, amounts, data)
            );
            if (success && result.length >= 32) {
                bytes4 response = abi.decode(result, (bytes4));
                require(response == 0xbc197c81, "ERC1155: rejected");
            } else {
                revert("ERC1155: non-receiver");
            }
        }
    }
}