// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract SimpleBridge {
    address public owner;
    uint256 public depositNonce;
    mapping(bytes32 => bool) public processed;

    event Deposited(address indexed from, address indexed to, uint256 amount, uint256 nonce, uint256 dstChainId);
    event Claimed(uint256 indexed srcChainId, address indexed from, address indexed to, uint256 amount, uint256 nonce);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function deposit(uint256 dstChainId, address to) external payable {
        require(to != address(0), "Invalid recipient");
        require(msg.value > 0, "No value");
        uint256 nonce = ++depositNonce;
        emit Deposited(msg.sender, to, msg.value, nonce, dstChainId);
    }

    function claim(
        uint256 srcChainId,
        address from,
        address to,
        uint256 amount,
        uint256 nonce
    ) external onlyOwner {
        require(to != address(0), "Invalid recipient");
        require(amount > 0, "No amount");
        bytes32 id = keccak256(abi.encode(srcChainId, from, to, amount, nonce));
        require(!processed[id], "Already processed");
        processed[id] = true;
        (bool ok, ) = payable(to).call{value: amount}("");
        require(ok, "ETH transfer failed");
        emit Claimed(srcChainId, from, to, amount, nonce);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Zero owner");
        owner = newOwner;
    }

    receive() external payable {}
}