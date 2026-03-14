// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract ERC1155MultiToken {
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 indexed tokenId, uint256 value);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    struct Token {
        uint256 id;
        address creator;
        string name;
        string symbol;
        uint256 supply;
        mapping(address => uint256) balances;
        mapping(address => mapping(address => uint256)) allowances;
    }

    Token[] public tokens;

    function mint(address to, uint256 tokenId, uint256 value) public {
        require(msg.sender == tokens[tokenId].creator, "Only the creator can mint");
        require(tokens[tokenId].supply + value <= tokens[tokenId].supply, "Insufficient supply");

        tokens[tokenId].supply += value;
        tokens[tokenId].balances[to] += value;

        emit Transfer(msg.sender, to, tokenId, value);
    }

    function transfer(address from, address to, uint256 tokenId, uint256 value) public {
        require(msg.sender == tokens[tokenId].creator, "Only the creator can transfer");
        require(tokens[tokenId].balances[from] >= value, "Insufficient balance");

        tokens[tokenId].balances[from] -= value;
        tokens[tokenId].balances[to] += value;

        emit Transfer(from, to, tokenId, value);
    }

    function approve(address spender, uint256 tokenId, uint256 value) public {
        require(msg.sender == tokens[tokenId].creator, "Only the creator can approve");
        require(tokens[tokenId].allowances[msg.sender][spender] + value <= tokens[tokenId].supply, "Insufficient allowance");

        tokens[tokenId].allowances[msg.sender][spender] += value;

        emit Approval(msg.sender, spender, tokenId, value);
    }

    function transferFrom(address from, address to, uint256 tokenId, uint256 value) public {
        require(msg.sender == tokens[tokenId].creator, "Only the creator can transfer");
        require(tokens[tokenId].balances[from] >= value, "Insufficient balance");
        require(tokens[tokenId].allowances[from][msg.sender] >= value, "Insufficient allowance");

        tokens[tokenId].balances[from] -= value;
        tokens[tokenId].balances[to] += value;

        emit Transfer(from, to, tokenId, value);
    }

    function balanceOf(address owner, uint256 tokenId) public view returns (uint256) {
        return tokens[tokenId].balances[owner];
    }

    function allowance(address owner, address spender, uint256 tokenId) public view returns (uint256) {
        return tokens[tokenId].allowances[owner][spender];
    }
}