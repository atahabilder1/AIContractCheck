pragma solidity ^0.6.0;

contract MyToken is ERC20 {
  string public name;
  string public symbol;
  uint8 public decimals;
  uint256 public totalSupply;

  constructor(string memory _name, string memory _symbol, uint8 _decimals, uint256 _totalSupply) public {
    name = _name;
    symbol = _symbol;
    decimals = _decimals;
    totalSupply = _totalSupply;
  }

  function transfer(address _to, uint256 _value) public returns (bool) {
    require(_value <= balanceOf(msg.sender));
    balanceOf[msg.sender] -= _value;
    balanceOf[_to] += _value;
    emit Transfer(msg.sender, _to, _value);
    return true;
  }

  function balanceOf(address _owner) public view returns (uint256) {
    return balanceOf[_owner];
  }
}

SPDX-License-Identifier: MIT
```