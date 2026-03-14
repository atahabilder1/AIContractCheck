// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract NFTEscrow is IERC721Receiver {
    enum SwapState { Created, NFTDeposited, Completed, Cancelled }

    struct Swap {
        address seller;
        address buyer;
        address nftContract;
        uint256 tokenId;
        uint256 price;
        SwapState state;
    }

    uint256 public nextSwapId;
    mapping(uint256 => Swap) public swaps;

    event SwapCreated(uint256 indexed swapId, address indexed seller, address nftContract, uint256 tokenId, uint256 price);
    event NFTDeposited(uint256 indexed swapId);
    event SwapCompleted(uint256 indexed swapId, address indexed buyer);
    event SwapCancelled(uint256 indexed swapId);

    function createSwap(
        address _nftContract,
        uint256 _tokenId,
        uint256 _price,
        address _buyer
    ) external returns (uint256 swapId) {
        require(_price > 0, "Price must be > 0");
        require(_nftContract != address(0), "Invalid NFT contract");

        swapId = nextSwapId++;
        swaps[swapId] = Swap({
            seller: msg.sender,
            buyer: _buyer,
            nftContract: _nftContract,
            tokenId: _tokenId,
            price: _price,
            state: SwapState.Created
        });

        emit SwapCreated(swapId, msg.sender, _nftContract, _tokenId, _price);
    }

    function depositNFT(uint256 _swapId) external {
        Swap storage swap = swaps[_swapId];
        require(swap.state == SwapState.Created, "Invalid state");
        require(msg.sender == swap.seller, "Only seller");

        swap.state = SwapState.NFTDeposited;
        IERC721(swap.nftContract).safeTransferFrom(msg.sender, address(this), swap.tokenId);

        emit NFTDeposited(_swapId);
    }

    function buyNFT(uint256 _swapId) external payable {
        Swap storage swap = swaps[_swapId];
        require(swap.state == SwapState.NFTDeposited, "NFT not deposited");
        require(swap.buyer == address(0) || swap.buyer == msg.sender, "Not authorized buyer");
        require(msg.value == swap.price, "Incorrect ETH amount");

        swap.state = SwapState.Completed;

        IERC721(swap.nftContract).safeTransferFrom(address(this), msg.sender, swap.tokenId);

        (bool sent, ) = swap.seller.call{value: msg.value}("");
        require(sent, "ETH transfer failed");

        emit SwapCompleted(_swapId, msg.sender);
    }

    function cancelSwap(uint256 _swapId) external {
        Swap storage swap = swaps[_swapId];
        require(msg.sender == swap.seller, "Only seller");
        require(swap.state == SwapState.Created || swap.state == SwapState.NFTDeposited, "Cannot cancel");

        SwapState previousState = swap.state;
        swap.state = SwapState.Cancelled;

        if (previousState == SwapState.NFTDeposited) {
            IERC721(swap.nftContract).safeTransferFrom(address(this), swap.seller, swap.tokenId);
        }

        emit SwapCancelled(_swapId);
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}