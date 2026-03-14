pragma solidity ^0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";

contract WrappedToken is ERC20 {
    constructor(string memory name, string memory symbol, uint8 decimals) ERC20(name, symbol, decimals) public {
        // Initialize the wrapped token contract with the underlying asset
        _wrappedToken = new RebasingToken(name, symbol, decimals);
    }

    function wrappedToken() external view returns (address) {
        return _wrappedToken;
    }

    function normalize() external {
        // Normalize the wrapped token by minting a new token with the same balance as the underlying asset
        uint256 balance = _wrappedToken.balanceOf(msg.sender);
        _mint(msg.sender, balance);
    }
}