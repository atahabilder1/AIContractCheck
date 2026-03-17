// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC165 {
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

interface IERC1155 is IERC165 {
    event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value);
    event TransferBatch(address indexed operator, address indexed from, address indexed to, uint256[] ids, uint256[] values);
    event ApprovalForAll(address indexed account, address indexed operator, bool approved);
    event URI(string value, uint256 indexed id);

    function balanceOf(address account, uint256 id) external view returns (uint256);
    function balanceOfBatch(address[] calldata accounts, uint256[] calldata ids) external view returns (uint256[] memory);
    function setApprovalForAll(address operator, bool approved) external;
    function isApprovedForAll(address account, address operator) external view returns (bool);
    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes calldata data) external;
    function safeBatchTransferFrom(address from, address to, uint256[] calldata ids, uint256[] calldata amounts, bytes calldata data) external;
}

interface IERC1155MetadataURI is IERC1155 {
    function uri(uint256 id) external view returns (string memory);
}

interface IERC1155Receiver is IERC165 {
    function onERC1155Received(address operator, address from, uint256 id, uint256 value, bytes calldata data) external returns (bytes4);
    function onERC1155BatchReceived(address operator, address from, uint256[] calldata ids, uint256[] calldata values, bytes calldata data) external returns (bytes4);
}

contract ERC1155 is IERC1155MetadataURI {
    // ERC165 interface IDs
    bytes4 private constant _INTERFACE_ID_ERC165 = 0x01ffc9a7;
    bytes4 private constant _INTERFACE_ID_ERC1155 = 0xd9b67a26;
    bytes4 private constant _INTERFACE_ID_ERC1155_METADATA_URI = 0x0e89341c;

    // ERC1155Receiver return values
    bytes4 private constant _ERC1155_RECEIVED = 0xf23a6e61;
    bytes4 private constant _ERC1155_BATCH_RECEIVED = 0xbc197c81;

    // token id => (account => balance)
    mapping(uint256 => mapping(address => uint256)) private _balances;

    // account => (operator => approved)
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    // base metadata URI
    string private _baseURI;

    // simple ownership
    address public owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor(string memory baseURI_) {
        owner = msg.sender;
        _setURI(baseURI_);
    }

    // IERC165
    function supportsInterface(bytes4 interfaceId) public pure override returns (bool) {
        return
            interfaceId == _INTERFACE_ID_ERC165 ||
            interfaceId == _INTERFACE_ID_ERC1155 ||
            interfaceId == _INTERFACE_ID_ERC1155_METADATA_URI;
    }

    // IERC1155MetadataURI
    function uri(uint256) public view override returns (string memory) {
        return _baseURI;
    }

    // IERC1155
    function balanceOf(address account, uint256 id) public view override returns (uint256) {
        require(account != address(0), "Zero address");
        return _balances[id][account];
    }

    function balanceOfBatch(address[] calldata accounts, uint256[] calldata ids) external view override returns (uint256[] memory) {
        require(accounts.length == ids.length, "Length mismatch");

        uint256[] memory batchBalances = new uint256[](accounts.length);
        for (uint256 i = 0; i < accounts.length; i++) {
            require(accounts[i] != address(0), "Zero address");
            batchBalances[i] = _balances[ids[i]][accounts[i]];
        }
        return batchBalances;
    }

    function setApprovalForAll(address operator, bool approved) external override {
        require(msg.sender != operator, "Self approval");
        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function isApprovedForAll(address account, address operator) public view override returns (bool) {
        return _operatorApprovals[account][operator];
    }

    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes calldata data) external override {
        require(to != address(0), "Zero to");
        address operator = msg.sender;
        require(from == operator || isApprovedForAll(from, operator), "Not authorized");

        _safeTransfer(from, to, id, amount, data);
    }

    function safeBatchTransferFrom(address from, address to, uint256[] calldata ids, uint256[] calldata amounts, bytes calldata data) external override {
        require(to != address(0), "Zero to");
        require(ids.length == amounts.length, "Length mismatch");
        address operator = msg.sender;
        require(from == operator || isApprovedForAll(from, operator), "Not authorized");

        _safeBatchTransfer(from, to, ids, amounts, data);
    }

    // Minting
    function mint(address to, uint256 id, uint256 amount, bytes calldata data) external onlyOwner {
        require(to != address(0), "Zero to");
        address operator = msg.sender;

        _balances[id][to] += amount;

        emit TransferSingle(operator, address(0), to, id, amount);

        _doSafeTransferAcceptanceCheck(operator, address(0), to, id, amount, data);
    }

    function mintBatch(address to, uint256[] calldata ids, uint256[] calldata amounts, bytes calldata data) external onlyOwner {
        require(to != address(0), "Zero to");
        require(ids.length == amounts.length, "Length mismatch");
        address operator = msg.sender;

        for (uint256 i = 0; i < ids.length; i++) {
            _balances[ids[i]][to] += amounts[i];
        }

        emit TransferBatch(operator, address(0), to, ids, amounts);

        _doSafeBatchTransferAcceptanceCheck(operator, address(0), to, ids, amounts, data);
    }

    // Burning
    function burn(address from, uint256 id, uint256 amount) external {
        address operator = msg.sender;
        require(from == operator || isApprovedForAll(from, operator), "Not authorized");

        uint256 fromBalance = _balances[id][from];
        require(fromBalance >= amount, "Insufficient balance");
        unchecked {
            _balances[id][from] = fromBalance - amount;
        }

        emit TransferSingle(operator, from, address(0), id, amount);
    }

    function burnBatch(address from, uint256[] calldata ids, uint256[] calldata amounts) external {
        require(ids.length == amounts.length, "Length mismatch");
        address operator = msg.sender;
        require(from == operator || isApprovedForAll(from, operator), "Not authorized");

        for (uint256 i = 0; i < ids.length; i++) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];
            uint256 fromBalance = _balances[id][from];
            require(fromBalance >= amount, "Insufficient balance");
            unchecked {
                _balances[id][from] = fromBalance - amount;
            }
        }

        emit TransferBatch(operator, from, address(0), ids, amounts);
    }

    // Admin URI
    function setURI(string calldata newuri) external onlyOwner {
        _setURI(newuri);
    }

    // Internal helpers
    function _setURI(string memory newuri) internal {
        _baseURI = newuri;
        emit URI(newuri, 0);
    }

    function _safeTransfer(address from, address to, uint256 id, uint256 amount, bytes calldata data) internal {
        uint256 fromBalance = _balances[id][from];
        require(fromBalance >= amount, "Insufficient balance");
        unchecked {
            _balances[id][from] = fromBalance - amount;
            _balances[id][to] += amount;
        }

        emit TransferSingle(msg.sender, from, to, id, amount);

        _doSafeTransferAcceptanceCheck(msg.sender, from, to, id, amount, data);
    }

    function _safeBatchTransfer(address from, address to, uint256[] calldata ids, uint256[] calldata amounts, bytes calldata data) internal {
        for (uint256 i = 0; i < ids.length; i++) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];

            uint256 fromBalance = _balances[id][from];
            require(fromBalance >= amount, "Insufficient balance");
            unchecked {
                _balances[id][from] = fromBalance - amount;
                _balances[id][to] += amount;
            }
        }

        emit TransferBatch(msg.sender, from, to, ids, amounts);

        _doSafeBatchTransferAcceptanceCheck(msg.sender, from, to, ids, amounts, data);
    }

    function _doSafeTransferAcceptanceCheck(address operator, address from, address to, uint256 id, uint256 amount, bytes calldata data) private {
        if (_isContract(to)) {
            try IERC1155Receiver(to).onERC1155Received(operator, from, id, amount, data) returns (bytes4 response) {
                require(response == _ERC1155_RECEIVED, "Receiver rejected");
            } catch {
                revert("Receiver invalid");
            }
        }
    }

    function _doSafeBatchTransferAcceptanceCheck(address operator, address from, address to, uint256[] calldata ids, uint256[] calldata amounts, bytes calldata data) private {
        if (_isContract(to)) {
            try IERC1155Receiver(to).onERC1155BatchReceived(operator, from, ids, amounts, data) returns (bytes4 response) {
                require(response == _ERC1155_BATCH_RECEIVED, "Receiver rejected");
            } catch {
                revert("Receiver invalid");
            }
        }
    }

    function _isContract(address account) private view returns (bool) {
        return account.code.length > 0;
    }
}