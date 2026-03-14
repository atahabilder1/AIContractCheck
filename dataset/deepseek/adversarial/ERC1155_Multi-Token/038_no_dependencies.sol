// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC1155 {
    function balanceOf(address account, uint256 id) external view returns (uint256);
    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes memory data) external;
    function setApprovalForAll(address operator, bool approved) external;
    function isApprovedForAll(address owner, address operator) external view returns (bool);
}

interface IERC165 {
    function supportsInterface(bytes4 interfaceId) external pure returns (bool);
}

contract ERC1155 is IERC165 {
    mapping(uint256 => uint256) public balances;
    mapping(address => mapping(address => bool)) public operatorApprovals;

    event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 amount);
    event TransferBatch(address indexed operator, address indexed from, address indexed to, uint256[] ids, uint256[] amounts);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    function supportsInterface(bytes4 interfaceId) public pure override returns (bool) {
        return interfaceId == type(IERC1155).interfaceId || interfaceId == type(IERC165).interfaceId;
    }

    function balanceOf(address account, uint256 id) public view returns (uint256) {
        return balances[id];
    }

    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes memory data) public {
        require(to != address(0), "ERC1155: transfer to the zero address");
        require(from == msg.sender || operatorApprovals[from][msg.sender], "ERC1155: insufficient authorization");

        balances[id] -= amount;
        balances[id] += amount;

        emit TransferSingle(msg.sender, from, to, id, amount);
        emit TransferBatch(msg.sender, from, to, new uint256[](1), new uint256[](1));

        if (to.code.length > 0) {
            require(IERC1155TokenReceiver(to).onERC1155Received(msg.sender, from, id, amount, data) == 0x150b7a02, "ERC1155: transfer to non-ERC1155Receiver implementer");
        }
    }

    function setApprovalForAll(address operator, bool approved) public {
        operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function isApprovedForAll(address owner, address operator) public view returns (bool) {
        return operatorApprovals[owner][operator];
    }
}

interface IERC1155TokenReceiver {
    function onERC1155Received(address operator, address from, uint256 id, uint256 amount, bytes memory data) external returns (bytes4);
}