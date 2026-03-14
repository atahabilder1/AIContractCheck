// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract ERC1155 {
    mapping(address => mapping(uint256 => uint256)) public balanceOf;
    mapping(address => mapping(address => bool)) public isApprovedForAll;

    event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value);
    event TransferBatch(address indexed operator, address indexed from, address indexed to, uint256[] ids, uint256[] values);
    event ApprovalForAll(address indexed account, address indexed operator, bool approved);
    event URI(string value, uint256 indexed id);

    address public owner;

    constructor() { owner = msg.sender; }

    function setApprovalForAll(address operator, bool approved) external {
        isApprovedForAll[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes calldata data) external {
        require(msg.sender == from || isApprovedForAll[from][msg.sender]);
        balanceOf[from][id] -= amount;
        unchecked { balanceOf[to][id] += amount; }
        emit TransferSingle(msg.sender, from, to, id, amount);
        if (to.code.length > 0) {
            require(IERC1155Receiver(to).onERC1155Received(msg.sender, from, id, amount, data) == 0xf23a6e61);
        }
    }

    function safeBatchTransferFrom(address from, address to, uint256[] calldata ids, uint256[] calldata amounts, bytes calldata data) external {
        require(msg.sender == from || isApprovedForAll[from][msg.sender]);
        uint256 len = ids.length;
        require(len == amounts.length);
        for (uint256 i; i < len;) {
            balanceOf[from][ids[i]] -= amounts[i];
            unchecked { balanceOf[to][ids[i]] += amounts[i]; ++i; }
        }
        emit TransferBatch(msg.sender, from, to, ids, amounts);
        if (to.code.length > 0) {
            require(IERC1155Receiver(to).onERC1155BatchReceived(msg.sender, from, ids, amounts, data) == 0xbc197c81);
        }
    }

    function balanceOfBatch(address[] calldata accounts, uint256[] calldata ids) external view returns (uint256[] memory out) {
        uint256 len = accounts.length;
        require(len == ids.length);
        out = new uint256[](len);
        for (uint256 i; i < len;) {
            out[i] = balanceOf[accounts[i]][ids[i]];
            unchecked { ++i; }
        }
    }

    function mint(address to, uint256 id, uint256 amount) external {
        require(msg.sender == owner);
        unchecked { balanceOf[to][id] += amount; }
        emit TransferSingle(msg.sender, address(0), to, id, amount);
        if (to.code.length > 0) {
            require(IERC1155Receiver(to).onERC1155Received(msg.sender, address(0), id, amount, "") == 0xf23a6e61);
        }
    }

    function mintBatch(address to, uint256[] calldata ids, uint256[] calldata amounts) external {
        require(msg.sender == owner);
        uint256 len = ids.length;
        require(len == amounts.length);
        for (uint256 i; i < len;) {
            unchecked { balanceOf[to][ids[i]] += amounts[i]; ++i; }
        }
        emit TransferBatch(msg.sender, address(0), to, ids, amounts);
        if (to.code.length > 0) {
            require(IERC1155Receiver(to).onERC1155BatchReceived(msg.sender, address(0), ids, amounts, "") == 0xbc197c81);
        }
    }

    function burn(address from, uint256 id, uint256 amount) external {
        require(msg.sender == from || isApprovedForAll[from][msg.sender]);
        balanceOf[from][id] -= amount;
        emit TransferSingle(msg.sender, from, address(0), id, amount);
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == 0xd9b67a26 || interfaceId == 0x0e89341c || interfaceId == 0x01ffc9a7;
    }
}

interface IERC1155Receiver {
    function onERC1155Received(address, address, uint256, uint256, bytes calldata) external returns (bytes4);
    function onERC1155BatchReceived(address, address, uint256[] calldata, uint256[] calldata, bytes calldata) external returns (bytes4);
}