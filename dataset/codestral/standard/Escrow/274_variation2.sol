// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract NFTForETHEscrow {
    IERC721 public nftToken;

    constructor(address _nftToken) {
        nftToken = IERC721(_nftToken);
    }

    function depositNFT(uint256 _tokenId, address payable _seller, uint256 _price) public {
        require(_seller == msg.sender, "Only the seller can deposit");
        nftToken.transferFrom(_seller, address(this), _tokenId);
    }

    function releaseNFT(uint256 _tokenId, address payable _buyer) public {
        require(msg.value >= _price, "Insufficient ETH sent");
        nftToken.transferFrom(address(this), _buyer, _tokenId);
        _buyer.transfer(_price);
    }
}