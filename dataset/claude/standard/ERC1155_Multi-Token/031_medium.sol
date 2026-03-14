// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";

contract ERC1155RoyaltyCapped is ERC1155, Ownable, IERC2981 {
    struct RoyaltyInfo {
        address receiver;
        uint96 feeBasisPoints;
    }

    mapping(uint256 => uint256) public supplyCap;
    mapping(uint256 => uint256) public totalSupply;
    mapping(uint256 => RoyaltyInfo) private _royalties;

    error SupplyCapExceeded(uint256 tokenId);
    error SupplyCapAlreadySet(uint256 tokenId);
    error InvalidRoyaltyFee();
    error ArrayLengthMismatch();

    constructor(string memory uri_) ERC1155(uri_) Ownable(msg.sender) {}

    function setSupplyCap(uint256 tokenId, uint256 cap) external onlyOwner {
        if (supplyCap[tokenId] != 0) revert SupplyCapAlreadySet(tokenId);
        supplyCap[tokenId] = cap;
    }

    function setTokenRoyalty(uint256 tokenId, address receiver, uint96 feeBasisPoints) external onlyOwner {
        if (feeBasisPoints > 10000) revert InvalidRoyaltyFee();
        _royalties[tokenId] = RoyaltyInfo(receiver, feeBasisPoints);
    }

    function mint(address to, uint256 tokenId, uint256 amount, bytes calldata data) external onlyOwner {
        _checkSupplyCap(tokenId, amount);
        totalSupply[tokenId] += amount;
        _mint(to, tokenId, amount, data);
    }

    function mintBatch(
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) external onlyOwner {
        if (ids.length != amounts.length) revert ArrayLengthMismatch();
        for (uint256 i = 0; i < ids.length; i++) {
            _checkSupplyCap(ids[i], amounts[i]);
            totalSupply[ids[i]] += amounts[i];
        }
        _mintBatch(to, ids, amounts, data);
    }

    function royaltyInfo(uint256 tokenId, uint256 salePrice)
        external
        view
        override
        returns (address receiver, uint256 royaltyAmount)
    {
        RoyaltyInfo memory royalty = _royalties[tokenId];
        receiver = royalty.receiver;
        royaltyAmount = (salePrice * royalty.feeBasisPoints) / 10000;
    }

    function setURI(string memory newuri) external onlyOwner {
        _setURI(newuri);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC1155, IERC165)
        returns (bool)
    {
        return interfaceId == type(IERC2981).interfaceId || super.supportsInterface(interfaceId);
    }

    function _checkSupplyCap(uint256 tokenId, uint256 amount) internal view {
        uint256 cap = supplyCap[tokenId];
        if (cap != 0 && totalSupply[tokenId] + amount > cap) {
            revert SupplyCapExceeded(tokenId);
        }
    }
}