// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract NFT is ERC721 {
    // Mapping of token IDs to their owners
    mapping(uint256 => address) private _owners;

    // Mapping of token IDs to their approved operators
    mapping(uint256 => mapping(address => bool)) private _approved;

    // Mapping of token IDs to their metadata
    mapping(uint256 => bytes32) private _metadata;

    // Mapping of token IDs to their supply
    mapping(uint256 => uint256) private _supply;

    // Event emitted when a token is minted
    event Minted(address indexed owner, uint256 indexed tokenId, uint256 supply);

    // Event emitted when a token is transferred
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    // Event emitted when a token is approved
    event Approval(address indexed owner, address indexed operator, uint256 indexed tokenId);

    // Constructor function to initialize the contract
    constructor() public {
        // Initialize the owners mapping to an empty mapping
        _owners = new mapping(uint256 => address);
        // Initialize the approved mapping to an empty mapping
        _approved = new mapping(uint256 => mapping(address => bool));
        // Initialize the metadata mapping to an empty mapping
        _metadata = new mapping(uint256 => bytes32);
        // Initialize the supply mapping to an empty mapping
        _supply = new mapping(uint256 => uint256);
    }

    // Function to mint a new token
    function mint(address owner, uint256 tokenId, uint256 supply) public {
        // Require that the token ID is not already in use
        require(_owners[tokenId] == address(0), "Token ID already in use");
        // Require that the owner is not the zero address
        require(owner != address(0), "Owner cannot be the zero address");
        // Require that the supply is greater than or equal to one
        require(supply >= 1, "Supply must be greater than or equal to one");

        // Set the owner of the token to the provided address
        _owners[tokenId] = owner;
        // Set the approved operator of the token to the owner
        _approved[tokenId][owner] = true;
        // Set the metadata of the token to an empty bytes32 array
        _metadata[tokenId] = new bytes32[](0);
        // Set the supply of the token to the provided supply
        _supply[tokenId] = supply;

        // Emit the Minted event
        emit Minted(owner, tokenId, supply);
    }

    // Function to transfer a token from one owner to another
    function transfer(address from, address to, uint256 tokenId) public {
        // Require that the token ID is in use
        require(_owners[tokenId] != address(0), "Token ID not in use");
        // Require that the owner is not the zero address
        require(from != address(0), "From address cannot be the zero address");
        // Require that the new owner is not the zero address
        require(to != address(0), "To address cannot be the zero address");

        // Set the owner of the token to the new owner
        _owners[tokenId] = to;
        // Set the approved operator of the token to the new owner
        _approved[tokenId][to] = true;
        // Set the metadata of the token to an empty bytes32 array
        _metadata[tokenId] = new bytes32[](0);

        // Emit the Transfer event
        emit Transfer(from, to, tokenId);
    }

    // Function to approve an operator to transfer a token
    function approve(address operator, uint256 tokenId) public {
        // Require that the token ID is in use
        require(_owners[tokenId] != address(0), "Token ID not in use");
        // Require that the operator is not the zero address
        require(operator != address(0), "Operator cannot be the zero address");

        // Set the approved operator of the token to the provided operator
        _approved[tokenId][operator] = true;

        // Emit the Approval event
        emit Approval(msg.sender, operator, tokenId);
    }

    // Function to get the owner of a token
    function ownerOf(uint256 tokenId) public view returns (address) {
        // Require that the token ID is in use
        require(_owners[tokenId] != address(0), "Token ID not in use");

        // Return the owner of the token
        return _owners[tokenId];
    }

    // Function to get the approved operator of a token
    function getApproved(uint256 tokenId) public view returns (address) {
        // Require that the token ID is in use
        require(_owners[tokenId] != address(0), "Token ID not in use");

        // Return the approved operator of the token
        return _approved[tokenId][msg.sender];
    }

    // Function to set the metadata of a token
    function setMetadata(uint256 tokenId, bytes32 metadata) public {
        // Require that the token ID is in use
        require(_owners[tokenId] != address(0), "Token ID not in use");
        // Require that the metadata is not empty
        require(metadata.length != 0, "Metadata cannot be empty");

        // Set the metadata of the token to the provided metadata
        _metadata[tokenId] = metadata;

        // Emit the MetadataSet event
        emit MetadataSet(tokenId, metadata);
    }

    // Function to get the metadata of a token
    function getMetadata(uint256 tokenId) public view returns (bytes32) {
        // Require that the token ID is in use
        require(_owners[tokenId] != address(0), "Token ID not in use");

        // Return the metadata of the token
        return _metadata[tokenId];
    }

    // Function to get the supply of a token
    function getSupply(uint256 tokenId) public view returns (uint256) {
        // Require that the token ID is in use
        require(_owners[tokenId] != address(0), "Token ID not in use");

        // Return the supply of the token
        return _supply[tokenId];
    }

    // Function to get the total supply of all tokens
    function totalSupply() public view returns (uint256) {
        // Initialize the total supply to zero
        uint256 totalSupply = 0;

        // Loop through all token IDs
        for (uint256 i = 0; i < _owners.length; i++) {
            // Add the supply of the current token to the total supply
            totalSupply += _supply[i];
        }

        // Return the total supply
        return totalSupply;
    }
}