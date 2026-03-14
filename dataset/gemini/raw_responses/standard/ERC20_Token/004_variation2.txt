```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title FeeOnTransferToken
/// @dev An ERC20 token with a 2% fee on transfers, sent to a specified treasury address.
///      The treasury address itself is exempt from paying fees when sending tokens.
contract FeeOnTransferToken is ERC20, Ownable {
    // The address where transfer fees are sent.
    // Made immutable for security and simplicity, set at deployment.
    address private immutable _treasuryAddress;

    // The fee percentage