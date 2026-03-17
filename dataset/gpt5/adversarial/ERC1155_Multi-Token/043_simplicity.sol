// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC1155Receiver {
    function onERC1155Received(address operator, address from, uint256 id, uint256 value, bytes calldata data) external returns (bytes4);
    function onERC1155BatchReceived(address operator, address from, uint256[] calldata ids, uint256[] calldata values, bytes calldata data) external returns (bytes4);
}

contract MinimalERC1155 {
    // ERC165 interface IDs
    function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
        return
            interfaceId == 0x01ffc9a7 || // ERC165
            interfaceId == 0xd9b67a26 || // ERC1155
            interfaceId == 0x0e89341c;   // ERC1155Metadata_URI
    }

    // Events per ERC1155
    event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value);
    event TransferBatch(address indexed operator, address indexed from, address indexed to, uint256[] ids, uint256[] values);
    event ApprovalForAll(address indexed account, address indexed operator, bool approved);
    event URI(string value, uint256 indexed id);

    // Storage
    mapping(uint256 => mapping(address => uint256)) private _balances;
    mapping(address => mapping(address => bool)) private _operatorApprovals;
    string private _uri;

    // Minimal ownership for minting control
    address public owner;
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor(string memory uri_) {
        owner = msg.sender;
        _uri = uri_;
    }

    // ERC1155Metadata_URI
    function uri(uint256) public view returns (string memory) {
        return _uri;
    }

    // ERC1155 core
    function balanceOf(address account, uint256 id) public view returns (uint256) {
        require(account != address(0), "Zero address");
        return _balances[id][account];
    }

    function balanceOfBatch(address[] memory accounts, uint256[] memory ids) public view returns (uint256[] memory batchBalances) {
        require(accounts.length == ids.length, "Length mismatch");
        batchBalances = new uint256[](accounts.length);
        for (uint256 i = 0; i < accounts.length; ) {
            require(accounts[i] != address(0), "Zero address");
            batchBalances[i] = _balances[ids[i]][accounts[i]];
            unchecked { ++i; }
        }
    }

    function setApprovalForAll(address operator, bool approved) external {
        require(operator != msg.sender, "Self approval");
        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function isApprovedForAll(address account, address operator) public view returns (bool) {
        return _operatorApprovals[account][operator];
    }

    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes memory data) public {
        require(from == msg.sender || isApprovedForAll(from, msg.sender), "Not authorized");
        require(to != address(0), "Zero address");

        uint256 fromBalance = _balances[id][from];
        require(fromBalance >= amount, "Insufficient balance");
        unchecked {
            _balances[id][from] = fromBalance - amount;
        }
        _balances[id][to] += amount;

        emit TransferSingle(msg.sender, from, to, id, amount);
        _doSafeTransferAcceptanceCheck(msg.sender, from, to, id, amount, data);
    }

    function safeBatchTransferFrom(address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) public {
        require(from == msg.sender || isApprovedForAll(from, msg.sender), "Not authorized");
        require(to != address(0), "Zero address");
        require(ids.length == amounts.length, "Length mismatch");

        for (uint256 i = 0; i < ids.length; ) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];

            uint256 fromBalance = _balances[id][from];
            require(fromBalance >= amount, "Insufficient balance");
            unchecked {
                _balances[id][from] = fromBalance - amount;
            }
            _balances[id][to] += amount;

            unchecked { ++i; }
        }

        emit TransferBatch(msg.sender, from, to, ids, amounts);
        _doSafeBatchTransferAcceptanceCheck(msg.sender, from, to, ids, amounts, data);
    }

    // Minimal minting (owner-controlled)
    function mint(address to, uint256 id, uint256 amount, bytes memory data) external onlyOwner {
        require(to != address(0), "Zero address");

        _balances[id][to] += amount;
        emit TransferSingle(msg.sender, address(0), to, id, amount);
        _doSafeTransferAcceptanceCheck(msg.sender, address(0), to, id, amount, data);
    }

    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) external onlyOwner {
        require(to != address(0), "Zero address");
        require(ids.length == amounts.length, "Length mismatch");

        for (uint256 i = 0; i < ids.length; ) {
            _balances[ids[i]][to] += amounts[i];
            unchecked { ++i; }
        }

        emit TransferBatch(msg.sender, address(0), to, ids, amounts);
        _doSafeBatchTransferAcceptanceCheck(msg.sender, address(0), to, ids, amounts, data);
    }

    // Acceptance checks
    function _doSafeTransferAcceptanceCheck(address operator, address from, address to, uint256 id, uint256 amount, bytes memory data) private {
        if (to.code.length > 0) {
            try IERC1155Receiver(to).onERC1155Received(operator, from, id, amount, data) returns (bytes4 retval) {
                require(retval == IERC1155Receiver.onERC1155Received.selector, "Receiver rejected");
            } catch {
                revert("Receiver invalid");
            }
        }
    }

    function _doSafeBatchTransferAcceptanceCheck(address operator, address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) private {
        if (to.code.length > 0) {
            try IERC1155Receiver(to).onERC1155BatchReceived(operator, from, ids, amounts, data) returns (bytes4 retval) {
                require(retval == IERC1155Receiver.onERC1155BatchReceived.selector, "Receiver rejected");
            } catch {
                revert("Receiver invalid");
            }
        }
    }
}