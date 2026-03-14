// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract SemiFungibleTokenWithSerials is ERC1155, Ownable {
    // Mapping from token ID to individual serial number owner
    mapping(uint256 => mapping(uint256 => address)) private _serialOwners;
    // Mapping from token ID to total supply of serial numbers
    mapping(uint256 => uint256) private _totalSerials;

    constructor(string memory uri) ERC1155(uri) {}

    function mint(
        address to,
        uint256 id,
        uint256 serialNumber
    ) external onlyOwner {
        require(_serialOwners[id][serialNumber] == address(0), "Serial number already minted");
        _serialOwners[id][serialNumber] = to;
        _totalSerials[id] += 1;
        _mint(to, id, 1, "");
    }

    function ownerOf(uint256 id, uint256 serialNumber) public view returns (address) {
        return _serialOwners[id][serialNumber];
    }

    function totalSerials(uint256 id) public view returns (uint256) {
        return _totalSerials[id];
    }

    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal override {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
        
        if (from != address(0)) {
            for (uint256 i = 0; i < ids.length; ++i) {
                uint256 id = ids[i];
                for (uint256 serial = 1; serial <= _totalSerials[id]; serial++) {
                    if (_serialOwners[id][serial] == from) {
                        _serialOwners[id][serial] = to;
                        break;
                    }
                }
            }
        }
    }
}