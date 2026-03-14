// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-solidity/contracts/token/ERC1155/ERC1155.sol";

contract GasOptimizedERC1155MultiToken is ERC1155 {
    constructor() ERC1155("GasOptimizedERC1155MultiToken") {}

    function transfer(address _to, uint256 _tokenId, uint256 _amount) public override {
        require(_to != address(0), "Cannot transfer to the zero address");
        require(_amount > 0, "Invalid amount");
        require(_amount <= balanceOf(msg.sender, _tokenId), "Insufficient balance");

        _balances[msg.sender][_tokenId] -= _amount;
        _balances[_to][_tokenId] += _amount;

        emit Transfer(msg.sender, _to, _tokenId, _amount);
    }

    function transferFrom(address _from, address _to, uint256 _tokenId, uint256 _amount) public override {
        require(_to != address(0), "Cannot transfer to the zero address");
        require(_amount > 0, "Invalid amount");
        require(_amount <= balanceOf(_from, _tokenId), "Insufficient balance");

        _balances[_from][_tokenId] -= _amount;
        _balances[_to][_tokenId] += _amount;

        emit Transfer(_from, _to, _tokenId, _amount);
    }

    function batchTransfer(address _to, uint256[] memory _tokenIds, uint256[] memory _amounts) public override {
        require(_tokenIds.length == _amounts.length, "Invalid token IDs or amounts");

        for (uint256 i = 0; i < _tokenIds.length; i++) {
            transfer(_to, _tokenIds[i], _amounts[i]);
        }
    }

    function batchTransferFrom(address _from, address _to, uint256[] memory _tokenIds, uint256[] memory _amounts) public override {
        require(_tokenIds.length == _amounts.length, "Invalid token IDs or amounts");

        for (uint256 i = 0; i < _tokenIds.length; i++) {
            transferFrom(_from, _to, _tokenIds[i], _amounts[i]);
        }
    }
}