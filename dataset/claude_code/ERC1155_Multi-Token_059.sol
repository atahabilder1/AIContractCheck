// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Minimal ERC1155
contract MinimalERC1155 {
    mapping(uint256 => mapping(address => uint256)) public balanceOf;
    mapping(address => mapping(address => bool)) public isApprovedForAll;

    event TransferSingle(address indexed, address indexed, address indexed, uint256, uint256);
    event TransferBatch(address indexed, address indexed, address indexed, uint256[], uint256[]);
    event ApprovalForAll(address indexed, address indexed, bool);

    function setApprovalForAll(address op, bool ok) external {
        isApprovedForAll[msg.sender][op] = ok;
        emit ApprovalForAll(msg.sender, op, ok);
    }

    function safeTransferFrom(address from, address to, uint256 id, uint256 amt, bytes calldata) external {
        require(from == msg.sender || isApprovedForAll[from][msg.sender]);
        balanceOf[id][from] -= amt;
        balanceOf[id][to] += amt;
        emit TransferSingle(msg.sender, from, to, id, amt);
    }

    function safeBatchTransferFrom(address from, address to, uint256[] calldata ids, uint256[] calldata amts, bytes calldata) external {
        require(from == msg.sender || isApprovedForAll[from][msg.sender]);
        for (uint256 i = 0; i < ids.length; i++) {
            balanceOf[ids[i]][from] -= amts[i];
            balanceOf[ids[i]][to] += amts[i];
        }
        emit TransferBatch(msg.sender, from, to, ids, amts);
    }

    function mint(address to, uint256 id, uint256 amt) external {
        balanceOf[id][to] += amt;
        emit TransferSingle(msg.sender, address(0), to, id, amt);
    }
}
