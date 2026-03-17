// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract GameItems is ERC1155, ERC1155Supply, AccessControl, Pausable {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    string public name;
    string public symbol;

    // Tracks whether a token ID is non-fungible (true) or fungible (false)
    mapping(uint256 => bool) private _isNonFungible;
    mapping(uint256 => bool) private _isTypeSet;

    event TokenTypeSet(uint256 indexed id, bool isNonFungible);

    constructor(string memory baseURI, string memory _name, string memory _symbol) ERC1155(baseURI) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        name = _name;
        symbol = _symbol;
    }

    function setURI(string memory newuri) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setURI(newuri);
    }

    function setTokenType(uint256 id, bool isNonFungible_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(totalSupply(id) == 0, "GameItems: already minted");
        _isNonFungible[id] = isNonFungible_;
        _isTypeSet[id] = true;
        emit TokenTypeSet(id, isNonFungible_);
    }

    function isNonFungible(uint256 id) external view returns (bool) {
        return _isNonFungible[id];
    }

    function mintFungible(address to, uint256 id, uint256 amount, bytes memory data) external onlyRole(MINTER_ROLE) {
        require(amount > 0, "GameItems: amount is zero");
        if (!_isTypeSet[id]) {
            _isNonFungible[id] = false;
            _isTypeSet[id] = true;
            emit TokenTypeSet(id, false);
        } else {
            require(!_isNonFungible[id], "GameItems: ID is NFT");
        }
        _mint(to, id, amount, data);
    }

    function mintFungibleBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) external onlyRole(MINTER_ROLE) {
        require(ids.length == amounts.length, "GameItems: length mismatch");
        for (uint256 i = 0; i < ids.length; i++) {
            require(amounts[i] > 0, "GameItems: amount is zero");
            if (!_isTypeSet[ids[i]]) {
                _isNonFungible[ids[i]] = false;
                _isTypeSet[ids[i]] = true;
                emit TokenTypeSet(ids[i], false);
            } else {
                require(!_isNonFungible[ids[i]], "GameItems: ID is NFT");
            }
        }
        _mintBatch(to, ids, amounts, data);
    }

    function mintNonFungible(address to, uint256 id, bytes memory data) external onlyRole(MINTER_ROLE) {
        if (!_isTypeSet[id]) {
            _isNonFungible[id] = true;
            _isTypeSet[id] = true;
            emit TokenTypeSet(id, true);
        } else {
            require(_isNonFungible[id], "GameItems: ID is fungible");
        }
        require(totalSupply(id) == 0, "GameItems: NFT already minted");
        _mint(to, id, 1, data);
    }

    function burn(address from, uint256 id, uint256 amount) external {
        require(from == msg.sender || isApprovedForAll(from, msg.sender), "GameItems: not owner nor approved");
        _burn(from, id, amount);
    }

    function burnBatch(address from, uint256[] memory ids, uint256[] memory amounts) external {
        require(from == msg.sender || isApprovedForAll(from, msg.sender), "GameItems: not owner nor approved");
        _burnBatch(from, ids, amounts);
    }

    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal whenNotPaused override(ERC1155, ERC1155Supply) {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC1155, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}