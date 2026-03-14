// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MultiToken is ERC1155, Ownable {
    mapping(uint256 => string) private _tokenURIs;
    uint256 public nextTokenId;

    constructor() ERC1155("") Ownable(msg.sender) {}

    function mint(address to, uint256 id, uint256 amount, bytes memory data) external onlyOwner {
        _mint(to, id, amount, data);
    }

    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) external onlyOwner {
        _mintBatch(to, ids, amounts, data);
    }

    function create(uint256 initialSupply, string memory tokenURI) external onlyOwner returns (uint256) {
        uint256 id = nextTokenId++;
        _mint(msg.sender, id, initialSupply, "");
        _tokenURIs[id] = tokenURI;
        return id;
    }

    function setURI(uint256 id, string memory tokenURI) external onlyOwner {
        _tokenURIs[id] = tokenURI;
    }

    function uri(uint256 id) public view override returns (string memory) {
        string memory tokenURI = _tokenURIs[id];
        if (bytes(tokenURI).length > 0) {
            return tokenURI;
        }
        return super.uri(id);
    }

    function burn(address from, uint256 id, uint256 amount) external {
        require(from == msg.sender || isApprovedForAll(from, msg.sender), "Not authorized");
        _burn(from, id, amount);
    }
}