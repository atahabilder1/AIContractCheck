// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title MinimalERC721
/// @dev A highly optimized, minimal implementation of the ERC721 standard.
///      Focuses on core EIP-721 functionality with reduced gas usage by avoiding
///      common overheads from more feature-rich implementations.
///      Does not include extensions like ERC721Enumerable or ERC721Metadata (URI storage).
///      Includes internal `_mint` and `_burn` functions for functionality,
///      which would typically be wrapped by public, permissioned functions in a full application.
contract MinimalERC721 {
    // --- State Variables ---

    string private _name