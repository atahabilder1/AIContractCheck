// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract MultiToken is ERC1155, Ownable {
    using Strings for uint256;

    constructor() ERC1155("https://your-metadata-endpoint/{id}.json") {}

    function _beforeTokenTransfer(address operator, address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes calldata data) internal override {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
        require(_isApprovedOrOwner(operator), "ERC1155: caller is not token owner or approved");
    }

    function _burn(address account, uint256 id, uint256 amount) internal virtual override {
        super._burn(account, id, amount);
        _decreaseSupply(id, amount);
    }
}