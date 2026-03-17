// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract CappedRoyaltyERC1155 is ERC1155, ERC2981, Ownable {
    // tokenId => max supply (cap)
    mapping(uint256 => uint256) private _supplyCap;
    // tokenId => total minted (cumulative, does not decrease on burn)
    mapping(uint256 => uint256) private _minted;

    event SupplyCapSet(uint256 indexed id, uint256 cap);

    constructor(
        string memory baseURI,
        address defaultRoyaltyReceiver,
        uint96 defaultRoyaltyFeeNumerator
    ) ERC1155(baseURI) {
        if (defaultRoyaltyReceiver != address(0) && defaultRoyaltyFeeNumerator > 0) {
            _setDefaultRoyalty(defaultRoyaltyReceiver, defaultRoyaltyFeeNumerator);
        }
    }

    // ----- Minting with supply caps -----

    function mint(address to, uint256 id, uint256 amount, bytes memory data) external onlyOwner {
        uint256 cap = _supplyCap[id];
        require(cap > 0, "Cap not set");
        uint256 mintedSoFar = _minted[id];
        require(mintedSoFar + amount <= cap, "Cap exceeded");

        _minted[id] = mintedSoFar + amount;
        _mint(to, id, amount, data);
    }

    function mintBatch(
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) external onlyOwner {
        require(ids.length == amounts.length, "Length mismatch");

        // Validate all caps first
        for (uint256 i = 0; i < ids.length; i++) {
            uint256 id = ids[i];
            uint256 cap = _supplyCap[id];
            require(cap > 0, "Cap not set");
            uint256 mintedSoFar = _minted[id];
            require(mintedSoFar + amounts[i] <= cap, "Cap exceeded");
        }

        // Update minted counters
        for (uint256 i = 0; i < ids.length; i++) {
            _minted[ids[i]] += amounts[i];
        }

        _mintBatch(to, ids, amounts, data);
    }

    // ----- Supply caps management -----

    function setTokenSupplyCap(uint256 id, uint256 cap) external onlyOwner {
        require(cap > 0, "Cap must be > 0");
        require(cap >= _minted[id], "Cap < minted");
        _supplyCap[id] = cap;
        emit SupplyCapSet(id, cap);
    }

    function supplyCapOf(uint256 id) external view returns (uint256) {
        return _supplyCap[id];
    }

    function mintedOf(uint256 id) external view returns (uint256) {
        return _minted[id];
    }

    // ----- Royalties (EIP-2981) -----

    function setTokenRoyalty(uint256 tokenId, address receiver, uint96 feeNumerator) external onlyOwner {
        _setTokenRoyalty(tokenId, receiver, feeNumerator);
    }

    function resetTokenRoyalty(uint256 tokenId) external onlyOwner {
        _resetTokenRoyalty(tokenId);
    }

    function setDefaultRoyalty(address receiver, uint96 feeNumerator) external onlyOwner {
        _setDefaultRoyalty(receiver, feeNumerator);
    }

    function deleteDefaultRoyalty() external onlyOwner {
        _deleteDefaultRoyalty();
    }

    // ----- URI management -----

    function setURI(string calldata newuri) external onlyOwner {
        _setURI(newuri);
    }

    // ----- Interface support -----

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC1155, ERC2981)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}