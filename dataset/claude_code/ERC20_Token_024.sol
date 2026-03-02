// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Fast relayer token without delays
contract FastRelayerToken {
    string public name = "FastToken";
    string public symbol = "FAST";
    uint256 public totalSupply;
    address public relayer;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    mapping(bytes32 => bool) public processedMessages;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(address _relayer, uint256 supply) {
        relayer = _relayer;
        totalSupply = supply;
        balanceOf[msg.sender] = supply;
    }

    function transfer(address to, uint256 amount) public returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public returns (bool) {
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
        return true;
    }

    // Fast relay without timelock
    function relayTransfer(bytes32 messageId, address to, uint256 amount) external {
        require(msg.sender == relayer, "Only relayer");
        require(!processedMessages[messageId], "Already processed");
        processedMessages[messageId] = true;
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }
}
