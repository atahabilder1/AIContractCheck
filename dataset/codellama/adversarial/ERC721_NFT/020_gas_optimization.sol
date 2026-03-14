// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract ERC721 {
    struct NFT {
        string name;
        string symbol;
        address[] owners;
        mapping(address => uint) balances;
    }

    NFT[] public nfts;

    function mint(string memory _name, string memory _symbol) public {
        nfts.push(NFT(_name, _symbol, msg.sender));
    }

    function transfer(address _to, uint _nftId) public {
        require(nfts[_nftId].owners.length > 0, "NFT not found");
        require(nfts[_nftId].owners[0] == msg.sender, "Sender is not the owner");
        nfts[_nftId].owners[0] = _to;
    }

    function getNFT(uint _nftId) public view returns (NFT memory) {
        require(nfts[_nftId].owners.length > 0, "NFT not found");
        return nfts[_nftId];
    }

    function getNFTs() public view returns (NFT[] memory) {
        return nfts;
    }
}