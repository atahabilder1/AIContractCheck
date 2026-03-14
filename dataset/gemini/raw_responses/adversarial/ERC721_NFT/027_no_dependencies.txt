```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @dev Required external contract interface for ERC721 safe transfers.
 */
interface IERC721Receiver {
    /**
     * @dev Whenever an {IERC721} `tokenId` is transferred to `to` via {IERC721-safeTransferFrom}
     * by `operator` from `from`, this function is called on `to`.
     *
     * If `to` is a smart contract, it must implement this function and return the
     * `bytes4` selector of this function to acknowledge the receipt of the NFT.
     * If the smart contract is not prepared