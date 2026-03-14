// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract CrossChainBridge is Ownable {
    IERC20 public immutable token;
    uint256 public constant SLASH_AMOUNT = 100; // Example slash amount

    struct Validator {
        bool active;
        uint256 stake;
    }

    mapping(address => Validator) public validators;

    event TokensStaked(address indexed validator, uint256 amount);
    event MessageSent(bytes message, address indexed validator);
    event MessageInvalid(bytes message, address indexed validator);

    constructor(address _tokenAddress) {
        token = IERC20(_tokenAddress);
    }

    function stakeTokens(uint256 amount) external {
        require(amount > 0, "Amount must be greater than zero");
        require(token.transferFrom(msg.sender, address(this), amount), "Token transfer failed");
        if (validators[msg.sender].active) {
            validators[msg.sender].stake += amount;
        } else {
            validators[msg.sender] = Validator({active: true, stake: amount});
        }
        emit TokensStaked(msg.sender, amount);
    }

    function sendMessage(bytes memory message) external {
        require(validators[msg.sender].active, "Validator not active");
        // Simulate sending a message and checking its validity
        if (isValidMessage(message)) {
            emit MessageSent(message, msg.sender);
        } else {
            slashValidator(msg.sender);
            emit MessageInvalid(message, msg.sender);
        }
    }

    function isValidMessage(bytes memory message) internal pure returns (bool) {
        // Implement your message validation logic here
        // For example, check if the message is not empty
        return message.length > 0;
    }

    function slashValidator(address validator) internal {
        require(validators[validator].active, "Validator not active");
        validators[validator].stake -= SLASH_AMOUNT;
        if (validators[validator].stake == 0) {
            validators[validator].active = false;
        }
    }
}