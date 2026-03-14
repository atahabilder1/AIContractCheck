// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";

contract SemiFungibleToken is ERC1155, Ownable, ERC1155Supply {
    mapping(uint256 => uint256) private _tokenSerialNumbers;

    constructor() ERC1155("") {}

    function setURI(string memory newuri) public onlyOwner {
        _setURI(newuri);
    }

    function mint(address account, uint256 id, uint256 amount, bytes memory data) public onlyOwner {
        require(amount > 0, "Amount must be greater than zero");
        _mint(account, id, amount, data);
        if (amount > 1) {
            for (uint256 i = 1; i < amount; i++) {
                _tokenSerialNumbers[totalSupply() + i] = id;
            }
        }
    }

    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) public onlyOwner {
        require(ids.length == amounts.length, "ids and amounts length mismatch");
        for (uint256 i = 0; i < ids.length; i++) {
            require(amounts[i] > 0, "Amount must be greater than zero");
            _mint(to, ids[i], amounts[i], data);
            if (amounts[i] > 1) {
                for (uint256 j = 1; j < amounts[i]; j++) {
                    _tokenSerialNumbers[totalSupply() + j] = ids[i];
                }
            }
        }
    }

    function burn(address account, uint256 id, uint256 value) public {
        require(value > 0, "Burn amount must be greater than zero");
        _burn(account, id, value);
    }

    function burnBatch(address account, uint256[] memory ids, uint256[] memory values) public {
        require(ids.length == values.length, "ids and values length mismatch");
        for (uint256 i = 0; i < ids.length; i++) {
            require(values[i] > 0, "Burn amount must be greater than zero");
            _burn(account, ids[i], values[i]);
        }
    }

    function tokenSerialNumber(uint256 tokenId) public view returns (uint256) {
        return _tokenSerialNumbers[tokenId];
    }

    function _beforeTokenTransfer(address operator, address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) internal override(ERC1155, ERC1155Supply) {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
        for (uint256 i = 0; i < ids.length; i++) {
            if (amounts[i] > 1) {
                uint256 totalSupplyForId = totalSupply(ids[i]);
                for (uint256 j = 1; j < amounts[i]; j++) {
                    require(_tokenSerialNumbers[totalSupplyForId + j] == ids[i], "Invalid serial number");
                }
            }
        }
    }
}