// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IChainLink {
    function sendMessage(address _to, bytes memory _message) external returns (bool);
}

contract CrossChainMessaging {
    mapping(address => IERC20) public tokens;
    mapping(address => IChainLink) public chains;

    constructor() {}

    function registerToken(address _token, address _chain) public {
        require(_token != address(0), "Invalid token address");
        require(_chain != address(0), "Invalid chain address");
        tokens[_token] = IERC20(_token);
        chains[_chain] = IChainLink(_chain);
    }

    function batchSendMessages(address[] memory _tokens, uint256[] memory _amounts, bytes[] memory _messages) public {
        require(_tokens.length == _amounts.length && _tokens.length == _messages.length, "Input arrays must have the same length");

        for (uint i = 0; i < _tokens.length; i++) {
            IERC20 token = tokens[_tokens[i]];
            require(token != address(0), "Token not registered");
            token.transfer(_chains[_tokens[i]].address, _amounts[i]);
        }

        for (uint i = 0; i < _messages.length; i++) {
            chains[_tokens[i]].sendMessage(msg.sender, _messages[i]);
        }
    }
}