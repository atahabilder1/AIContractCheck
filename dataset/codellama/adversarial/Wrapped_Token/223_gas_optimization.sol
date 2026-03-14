// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract WrappedToken {
    // Mapping to keep track of the wrapped tokens
    mapping(address => uint256) public wrappedTokens;

    // Event to log the wrapping and unwrapping of tokens
    event Wrap(address indexed from, uint256 value);
    event Unwrap(address indexed to, uint256 value);

    // Modifier to check if the token is wrapped
    modifier isWrapped(address _token) {
        require(wrappedTokens[_token] > 0, "Token is not wrapped");
        _;
    }

    // Function to wrap a token
    function wrap(address _token) public isWrapped(_token) {
        // Get the current balance of the wrapped token
        uint256 balance = wrappedTokens[_token];

        // Transfer the wrapped token to the contract
        _token.transfer(address(this), balance);

        // Update the mapping to reflect the wrapped token
        wrappedTokens[_token] = balance;

        // Emit an event to log the wrapping
        emit Wrap(msg.sender, balance);
    }

    // Function to unwrap a token
    function unwrap(address _token) public isWrapped(_token) {
        // Get the current balance of the wrapped token
        uint256 balance = wrappedTokens[_token];

        // Transfer the wrapped token back to the sender
        _token.transfer(msg.sender, balance);

        // Update the mapping to reflect the unwrapped token
        wrappedTokens[_token] = 0;

        // Emit an event to log the unwrapping
        emit Unwrap(msg.sender, balance);
    }
}