// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract AdminERC1155 is ERC1155, Ownable, Pausable, ReentrancyGuard {
    string public name;
    string public symbol;

    mapping(uint256 => uint256) public tokenSupply;
    mapping(uint256 => uint256) public tokenPrices;
    mapping(uint256 => string) private _tokenURIs;

    event TokenMinted(address indexed to, uint256 indexed tokenId, uint256 amount);
    event TokenPriceSet(uint256 indexed tokenId, uint256 price);
    event EmergencyWithdrawal(address indexed admin, uint256 amount);

    constructor(
        string memory _name,
        string memory _symbol,
        string memory _uri
    ) ERC1155(_uri) Ownable(msg.sender) {
        name = _name;
        symbol = _symbol;
    }

    function mint(
        address to,
        uint256 tokenId,
        uint256 amount,
        bytes memory data
    ) external onlyOwner whenNotPaused {
        _mint(to, tokenId, amount, data);
        tokenSupply[tokenId] += amount;
        emit TokenMinted(to, tokenId, amount);
    }

    function mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) external onlyOwner whenNotPaused {
        _mintBatch(to, ids, amounts, data);
        for (uint256 i = 0; i < ids.length; i++) {
            tokenSupply[ids[i]] += amounts[i];
        }
    }

    function burn(uint256 tokenId, uint256 amount) external whenNotPaused {
        _burn(msg.sender, tokenId, amount);
        tokenSupply[tokenId] -= amount;
    }

    function setTokenPrice(uint256 tokenId, uint256 price) external onlyOwner {
        tokenPrices[tokenId] = price;
        emit TokenPriceSet(tokenId, price);
    }

    function purchase(uint256 tokenId, uint256 amount) external payable whenNotPaused nonReentrant {
        uint256 price = tokenPrices[tokenId];
        require(price > 0, "Token not for sale");
        require(msg.value == price * amount, "Incorrect payment");

        _mint(msg.sender, tokenId, amount, "");
        tokenSupply[tokenId] += amount;
        emit TokenMinted(msg.sender, tokenId, amount);
    }

    function setTokenURI(uint256 tokenId, string memory tokenURI) external onlyOwner {
        _tokenURIs[tokenId] = tokenURI;
        emit URI(tokenURI, tokenId);
    }

    function uri(uint256 tokenId) public view override returns (string memory) {
        string memory tokenURI = _tokenURIs[tokenId];
        if (bytes(tokenURI).length > 0) {
            return tokenURI;
        }
        return super.uri(tokenId);
    }

    // --- Admin Emergency Functions ---

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function emergencyWithdraw() external onlyOwner nonReentrant {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");

        (bool success, ) = payable(owner()).call{value: balance}("");
        require(success, "Withdrawal failed");

        emit EmergencyWithdrawal(msg.sender, balance);
    }

    function emergencyWithdrawTo(address payable recipient) external onlyOwner nonReentrant {
        require(recipient != address(0), "Invalid recipient");
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");

        (bool success, ) = recipient.call{value: balance}("");
        require(success, "Withdrawal failed");

        emit EmergencyWithdrawal(msg.sender, balance);
    }

    receive() external payable {}
}