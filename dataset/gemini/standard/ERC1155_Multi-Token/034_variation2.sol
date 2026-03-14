// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";

contract SemiFungibleERC1155 is ERC1155, ERC1155Supply, Ownable {

    // Mapping to store serial numbers for each token ID
    mapping(uint256 => mapping(uint256 => bool)) private _serialNumbers;

    // Event to log when a new serial number is minted for a token ID
    event SerialMinted(uint256 indexed id, uint256 indexed serialNumber, address indexed owner);

    constructor(string memory baseURI_) ERC1155(baseURI_) {}

    /**
     * @dev Mints a new semi-fungible token with a specific serial number.
     *      The token ID will be `baseTokenId + serialNumber`.
     * @param to The address to mint the token to.
     * @param baseTokenId The base ID for the semi-fungible token type.
     * @param serialNumber The unique serial number for this specific token instance.
     * @param amount The amount of this specific token instance to mint.
     * @param data Additional data to pass to the recipient.
     */
    function mintSemiFungible(
        address to,
        uint256 baseTokenId,
        uint256 serialNumber,
        uint256 amount,
        bytes memory data
    ) public onlyOwner {
        uint256 tokenId = baseTokenId + serialNumber;

        require(_serialNumbers[baseTokenId][serialNumber] == false, "SemiFungibleERC1155: Serial number already exists for this base token ID");
        require(amount > 0, "SemiFungibleERC1155: Amount must be greater than zero");

        _serialNumbers[baseTokenId][serialNumber] = true;

        _mint(to, tokenId, amount, data);
        emit SerialMinted(tokenId, serialNumber, to);
    }

    /**
     * @dev Mints multiple semi-fungible tokens with specific serial numbers.
     * @param to The address to mint the tokens to.
     * @param baseTokenIds An array of base token IDs.
     * @param serialNumbers An array of unique serial numbers for each base token ID.
     * @param amounts An array of amounts for each token instance.
     * @param data Additional data to pass to the recipient.
     */
    function mintBatchSemiFungible(
        address to,
        uint256[] memory baseTokenIds,
        uint256[] memory serialNumbers,
        uint256[] memory amounts,
        bytes memory data
    ) public onlyOwner {
        require(baseTokenIds.length == serialNumbers.length, "SemiFungibleERC1155: baseTokenIds and serialNumbers length mismatch");
        require(baseTokenIds.length == amounts.length, "SemiFungibleERC1155: baseTokenIds and amounts length mismatch");

        for (uint256 i = 0; i < baseTokenIds.length; i++) {
            uint256 baseTokenId = baseTokenIds[i];
            uint256 serialNumber = serialNumbers[i];
            uint256 amount = amounts[i];
            uint256 tokenId = baseTokenId + serialNumber;

            require(_serialNumbers[baseTokenId][serialNumber] == false, "SemiFungibleERC1155: Serial number already exists for this base token ID");
            require(amount > 0, "SemiFungibleERC1155: Amount must be greater than zero");

            _serialNumbers[baseTokenId][serialNumber] = true;
            emit SerialMinted(tokenId, serialNumber, to);
        }

        _mintBatch(to, _generateTokenIds(baseTokenIds, serialNumbers), amounts, data);
    }

    /**
     * @dev Helper function to generate token IDs from baseTokenIds and serialNumbers.
     */
    function _generateTokenIds(uint256[] memory baseTokenIds, uint256[] memory serialNumbers) internal pure returns (uint256[] memory) {
        uint256[] memory tokenIds = new uint256[](baseTokenIds.length);
        for (uint256 i = 0; i < baseTokenIds.length; i++) {
            tokenIds[i] = baseTokenIds[i] + serialNumbers[i];
        }
        return tokenIds;
    }

    /**
     * @dev Override the _update function to track supply.
     */
    function _update(address to, uint256 tokenId, uint256 newBalance, uint256, bytes memory data)
        internal
        override(ERC1155, ERC1155Supply)
        returns (uint256)
    {
        return super._update(to, tokenId, newBalance, data);
    }

    /**
     * @dev Override the uri function to support dynamic URIs.
     */
    function uri(uint256 tokenId)
        public
        view
        override(ERC1155)
        returns (string memory)
    {
        return super.uri(tokenId);
    }
}