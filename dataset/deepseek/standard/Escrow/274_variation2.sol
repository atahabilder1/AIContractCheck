// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract NFTEscrow {
    using SafeMath for uint256;

    IERC721 public nft;
    address public seller;
    address public buyer;
    uint256 public nftId;
    uint256 public price;
    bool public released;

    event Released(address indexed to, uint256 indexed tokenId);
    event Refunded(address indexed to, uint256 indexed tokenId);

    constructor(address _nft, uint256 _nftId, uint256 _price, address _seller, address _buyer) {
        nft = IERC721(_nft);
        seller = _seller;
        buyer = _buyer;
        nftId = _nftId;
        price = _price;
    }

    function release() external {
        require(msg.sender == buyer || msg.sender == seller, "Not authorized");
        require(!released, "Already released");
        require(nft.ownerOf(nftId) == address(this), "NFT not held by escrow");

        if (msg.sender == buyer) {
            require(address(this).balance >= price, "Insufficient balance in escrow");
            (bool success, ) = buyer.call{value: price}("");
            require(success, "Transfer failed");
        }

        nft.transferFrom(address(this), buyer, nftId);
        released = true;
        emit Released(buyer, nftId);
    }

    function refund() external {
        require(msg.sender == seller, "Not authorized");
        require(!released, "Already released");
        require(nft.ownerOf(nftId) == address(this), "NFT not held by escrow");

        nft.transferFrom(address(this), seller, nftId);
        (bool success, ) = seller.call{value: address(this).balance}("");
        require(success, "Transfer failed");
        released = true;
        emit Refunded(seller, nftId);
    }

    receive() external payable {}
}