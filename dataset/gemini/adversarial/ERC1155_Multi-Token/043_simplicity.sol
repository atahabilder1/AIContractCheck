// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract MinimalERC1155 is ERC1155 {
    constructor() ERC1155("ipfs://__metadata_uri__/metadata/") {}

    function mint(address to, uint256 id, uint256 amount, bytes memory data)
        public
        virtual
    {
        _mint(to, id, amount, data);
    }
}