// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TestnetMultiToken is ERC1155, ERC1155Supply, Ownable {
    string public name;
    string public symbol;

    constructor(string memory baseURI, string memory name_, string memory symbol_) ERC1155(baseURI) {
        name = name_;
        symbol = symbol_;
    }

    function setURI(string memory newuri) external onlyOwner {
        _setURI(newuri);
    }

    function mint(address to, uint256 id, uint256 amount, bytes memory data) external onlyOwner {
        _mint(to, id, amount, data);
    }

    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) external onlyOwner {
        _mintBatch(to, ids, amounts, data);
    }

    function airdrop(address[] calldata recipients, uint256 id, uint256 amountEach, bytes calldata data) external onlyOwner {
        require(amountEach > 0, "Amount must be > 0");
        for (uint256 i = 0; i < recipients.length; i++) {
            _mint(recipients[i], id, amountEach, data);
        }
    }

    function burn(address from, uint256 id, uint256 amount) external {
        require(from == _msgSender() || isApprovedForAll(from, _msgSender()), "Not owner or approved");
        _burn(from, id, amount);
    }

    function burnBatch(address from, uint256[] memory ids, uint256[] memory amounts) external {
        require(from == _msgSender() || isApprovedForAll(from, _msgSender()), "Not owner or approved");
        _burnBatch(from, ids, amounts);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC1155) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    // The following function is required by Solidity for multiple inheritance of hooks.
    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual override(ERC1155, ERC1155Supply) {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }
}