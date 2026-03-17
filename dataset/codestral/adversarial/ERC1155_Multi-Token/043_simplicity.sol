// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MinimalMultiToken is ERC1155, Ownable {
    constructor() ERC1155("https://your-metadata-url/{id}.json") {}

    function _beforeTokenTransfer(address operator, address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) internal override(ERC1155) {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }

    function _burn(address account, uint256 id, uint256 value) internal virtual override {
        super._burn(account, id, value);
    }
}