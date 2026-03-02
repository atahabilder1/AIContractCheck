// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Gas optimized ERC1155
contract GasOptimizedERC1155 {
    mapping(uint256 => mapping(address => uint256)) public balanceOf;
    mapping(address => mapping(address => bool)) public isApprovedForAll;

    event TransferSingle(address indexed, address indexed, address indexed, uint256, uint256);
    event TransferBatch(address indexed, address indexed, address indexed, uint256[], uint256[]);
    event ApprovalForAll(address indexed, address indexed, bool);

    function balanceOfBatch(address[] calldata accounts, uint256[] calldata ids) external view returns (uint256[] memory b) {
        b = new uint256[](accounts.length);
        for (uint256 i; i < accounts.length;) { b[i] = balanceOf[ids[i]][accounts[i]]; unchecked { ++i; } }
    }

    function setApprovalForAll(address op, bool ok) external {
        isApprovedForAll[msg.sender][op] = ok;
        emit ApprovalForAll(msg.sender, op, ok);
    }

    function safeTransferFrom(address from, address to, uint256 id, uint256 amt, bytes calldata) external {
        require(msg.sender == from || isApprovedForAll[from][msg.sender]);
        balanceOf[id][from] -= amt;
        unchecked { balanceOf[id][to] += amt; }
        emit TransferSingle(msg.sender, from, to, id, amt);
    }

    function safeBatchTransferFrom(address from, address to, uint256[] calldata ids, uint256[] calldata amts, bytes calldata) external {
        require(msg.sender == from || isApprovedForAll[from][msg.sender]);
        for (uint256 i; i < ids.length;) {
            balanceOf[ids[i]][from] -= amts[i];
            unchecked { balanceOf[ids[i]][to] += amts[i]; ++i; }
        }
        emit TransferBatch(msg.sender, from, to, ids, amts);
    }

    function mint(address to, uint256 id, uint256 amt) external {
        unchecked { balanceOf[id][to] += amt; }
        emit TransferSingle(msg.sender, address(0), to, id, amt);
    }

    function mintBatch(address to, uint256[] calldata ids, uint256[] calldata amts) external {
        for (uint256 i; i < ids.length;) { unchecked { balanceOf[ids[i]][to] += amts[i]; ++i; } }
        emit TransferBatch(msg.sender, address(0), to, ids, amts);
    }
}
