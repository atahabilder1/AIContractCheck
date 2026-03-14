// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract ERC1155 {
    // --- State Variables ---

    // balances[owner][id] -> amount
    mapping(address => mapping(uint256 => uint256)) private _balances;

    // mapping from token ID to owner address
    mapping(uint256 => address) private _ownerOf;

    // mapping from token ID to token URI
    mapping(uint256 => string) private _tokenURIs;

    // Total supply of each token
    mapping(uint256 => uint256) private _totalSupply;

    // _isApprovedForAll[owner][operator] -> approved
    mapping(address => mapping(address => bool)) private _isApprovedForAll;

    // Track the next available token ID
    uint256 private _nextTokenId = 0;

    // --- Events ---

    event TransferSingle(address operator, address from, address to, uint256 id, uint256 value);
    event TransferBatch(address operator, address from, address to, uint256[] ids, uint256[] values);
    event ApprovalForAll(address owner, address operator, bool approved);
    event URI(string value, uint256 indexed id);

    // --- Modifiers ---

    modifier onlyTokenOwner(uint256 _tokenId) {
        require(_ownerOf[_tokenId] == msg.sender, "ERC1155: caller is not token owner");
        _;
    }

    modifier onlyTokenOwnerOrApproved(uint256 _tokenId) {
        require(_ownerOf[_tokenId] == msg.sender || isApprovedForAll(_ownerOf[_tokenId], msg.sender), "ERC1155: caller is not token owner nor approved");
        _;
    }

    // --- Public Functions ---

    /**
     * @dev Returns the amount of tokens of the given token ID owned by the given address.
     * @param _owner Address of the owner
     * @param _id Token ID
     * @return Amount of tokens owned by the address
     */
    function balanceOf(address _owner, uint256 _id) external view returns (uint256) {
        return _balances[_owner][_id];
    }

    /**
     * @dev Returns the total supply of the given token ID.
     * @param _id Token ID
     * @return Total supply of the token
     */
    function totalSupply(uint256 _id) external view returns (uint256) {
        return _totalSupply[_id];
    }

    /**
     * @dev Returns the address of the owner of the given token ID.
     * @param _id Token ID
     * @return Address of the owner
     */
    function ownerOf(uint256 _id) external view returns (address) {
        return _ownerOf[_id];
    }

    /**
     * @dev Returns the URI for the given token ID.
     * @param _id Token ID
     * @return URI of the token
     */
    function uri(uint256 _id) external view returns (string memory) {
        return _tokenURIs[_id];
    }

    /**
     * @dev Returns whether or not any operator is approved to manage all of the owner's tokens.
     * @param _owner Address of the owner
     * @param _operator Address of the operator
     * @return True if the operator is approved, false otherwise
     */
    function isApprovedForAll(address _owner, address _operator) public view returns (bool) {
        return _isApprovedForAll[_owner][_operator];
    }

    /**
     * @dev Approves or removes an operator for all of an owner's tokens.
     * @param _operator Address to approve or remove
     * @param _approved True to approve, false to remove
     */
    function setApprovalForAll(address _operator, bool _approved) external {
        _isApprovedForAll[msg.sender][_operator] = _approved;
        emit ApprovalForAll(msg.sender, _operator, _approved);
    }

    /**
     * @dev Transfers a single token from the caller to a recipient.
     * @param _from Address of the sender
     * @param _to Address of the recipient
     * @param _id Token ID
     * @param _value Amount of tokens to transfer
     */
    function safeTransferFrom(address _from, address _to, uint256 _id, uint256 _value) public {
        require(_from == msg.sender || isApprovedForAll(_from, msg.sender), "ERC1155: caller is not owner nor approved");
        require(_to != address(0), "ERC1155: transfer to the zero address");
        require(_balances[_from][_id] >= _value, "ERC1155: insufficient balance for transfer");

        _balances[_from][_id] -= _value;
        _balances[_to][_id] += _value;

        emit TransferSingle(msg.sender, _from, _to, _id, _value);
    }

    /**
     * @dev Transfers multiple tokens from the caller to a recipient.
     * @param _from Address of the sender
     * @param _to Address of the recipient
     * @param _ids Array of token IDs
     * @param _values Array of amounts to transfer
     */
    function safeBatchTransferFrom(address _from, address _to, uint256[] memory _ids, uint256[] memory _values) public {
        require(_from == msg.sender || isApprovedForAll(_from, msg.sender), "ERC1155: caller is not owner nor approved");
        require(_to != address(0), "ERC1155: transfer to the zero address");
        require(_ids.length == _values.length, "ERC1155: ids and values length mismatch");

        for (uint256 i = 0; i < _ids.length; i++) {
            uint256 id = _ids[i];
            uint256 value = _values[i];
            require(_balances[_from][id] >= value, "ERC1155: insufficient balance for transfer");
        }

        for (uint256 i = 0; i < _ids.length; i++) {
            uint256 id = _ids[i];
            uint256 value = _values[i];
            _balances[_from][id] -= value;
            _balances[_to][id] += value;
        }

        emit TransferBatch(msg.sender, _from, _to, _ids, _values);
    }

    // --- Internal Functions ---

    /**
     * @dev Mints new tokens and assigns them to an address.
     * This function is intended for contract owner or authorized minter.
     * @param _to The address to mint tokens to.
     * @param _id The token ID of the tokens to mint.
     * @param _value The amount of tokens to mint.
     * @param _uri The URI for the token.
     */
    function mint(address _to, uint256 _id, uint256 _value, string memory _uri) internal {
        require(_to != address(0), "ERC1155: mint to the zero address");

        // If it's a new token, set its owner and URI
        if (_totalSupply[_id] == 0) {
            _ownerOf[_id] = _to; // The first minter becomes the owner
            _tokenURIs[_id] = _uri;
            emit URI(_uri, _id);
        } else {
            // If token exists, ensure the caller is the owner or approved
            require(msg.sender == _ownerOf[_id] || isApprovedForAll(_ownerOf[_id], msg.sender), "ERC1155: caller is not token owner nor approved");
            require(_tokenURIs[_id] == _uri, "ERC1155: URI mismatch for existing token");
        }

        _balances[_to][_id] += _value;
        _totalSupply[_id] += _value;

        emit TransferSingle(msg.sender, address(0), _to, _id, _value);
    }

    /**
     * @dev Mints new tokens in a batch and assigns them to an address.
     * This function is intended for contract owner or authorized minter.
     * @param _to The address to mint tokens to.
     * @param _ids Array of token IDs to mint.
     * @param _values Array of amounts of tokens to mint.
     * @param _uri The URI for the token.
     */
    function mintBatch(address _to, uint256[] memory _ids, uint256[] memory _values, string memory _uri) internal {
        require(_to != address(0), "ERC1155: mint to the zero address");
        require(_ids.length == _values.length, "ERC1155: ids and values length mismatch");

        for (uint256 i = 0; i < _ids.length; i++) {
            uint256 id = _ids[i];
            uint256 value = _values[i];

            // If it's a new token, set its owner and URI
            if (_totalSupply[id] == 0) {
                _ownerOf[id] = _to; // The first minter becomes the owner
                _tokenURIs[id] = _uri;
                emit URI(_uri, id);
            } else {
                // If token exists, ensure the caller is the owner or approved
                require(msg.sender == _ownerOf[id] || isApprovedForAll(_ownerOf[id], msg.sender), "ERC1155: caller is not token owner nor approved");
                require(_tokenURIs[id] == _uri, "ERC1155: URI mismatch for existing token");
            }

            _balances[_to][id] += value;
            _totalSupply[id] += value;
        }

        emit TransferBatch(msg.sender, address(0), _to, _ids, _values);
    }

    /**
     * @dev Burns tokens from an address.
     * @param _from Address of the owner to burn tokens from.
     * @param _id Token ID of the tokens to burn.
     * @param _value Amount of tokens to burn.
     */
    function burn(address _from, uint256 _id, uint256 _value) internal {
        require(_from == msg.sender || isApprovedForAll(_from, msg.sender), "ERC1155: caller is not owner nor approved");
        require(_balances[_from][_id] >= _value, "ERC1155: insufficient balance for burn");

        _balances[_from][_id] -= _value;
        _totalSupply[_id] -= _value;

        emit TransferSingle(msg.sender, _from, address(0), _id, _value);
    }

    /**
     * @dev Burns tokens in a batch from an address.
     * @param _from Address of the owner to burn tokens from.
     * @param _ids Array of token IDs to burn.
     * @param _values Array of amounts of tokens to burn.
     */
    function burnBatch(address _from, uint256[] memory _ids, uint256[] memory _values) internal {
        require(_from == msg.sender || isApprovedForAll(_from, msg.sender), "ERC1155: caller is not owner nor approved");
        require(_ids.length == _values.length, "ERC1155: ids and values length mismatch");

        for (uint256 i = 0; i < _ids.length; i++) {
            uint256 id = _ids[i];
            uint256 value = _values[i];
            require(_balances[_from][id] >= value, "ERC1155: insufficient balance for burn");
        }

        for (uint256 i = 0; i < _ids.length; i++) {
            uint256 id = _ids[i];
            uint256 value = _values[i];
            _balances[_from][id] -= value;
            _totalSupply[id] -= value;
        }

        emit TransferBatch(msg.sender, _from, address(0), _ids, _values);
    }

    /**
     * @dev Returns the next available token ID.
     * This is a helper function for creating new token types.
     * @return The next available token ID.
     */
    function getNextTokenId() public view returns (uint256) {
        return _nextTokenId;
    }

    /**
     * @dev Internal function to set the URI for a token.
     * @param _id Token ID.
     * @param _uri The URI to set.
     */
    function _setTokenURI(uint256 _id, string memory _uri) internal {
        _tokenURIs[_id] = _uri;
        emit URI(_uri, _id);
    }
}