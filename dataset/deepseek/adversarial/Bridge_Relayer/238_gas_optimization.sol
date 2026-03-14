// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
}

contract BridgeRelayer {
    address public owner;
    uint256 public fee;
    mapping(address => bool) public approvedTokens;

    event BridgeRelayed(address indexed token, address indexed to, uint256 amount, uint256 fee);
    event FeeUpdated(uint256 newFee);
    event TokenApproved(address indexed token, bool approved);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    constructor(uint256 _fee) {
        owner = msg.sender;
        fee = _fee;
    }

    function updateFee(uint256 _fee) external onlyOwner {
        fee = _fee;
        emit FeeUpdated(_fee);
    }

    function approveToken(address token, bool approved) external onlyOwner {
        approvedTokens[token] = approved;
        emit TokenApproved(token, approved);
    }

    function relay(address token, address to, uint256 amount) external payable {
        require(approvedTokens[token], "Token not approved");
        require(msg.value >= fee, "Insufficient fee");

        if (msg.value > fee) {
            // Refund the excess fee
            (bool success, ) = msg.sender.call{value: msg.value - fee}("");
            require(success, "Refund failed");
        }

        IERC20(token).transfer(to, amount);
        emit BridgeRelayed(token, to, amount, fee);
    }

    function withdrawFee() external onlyOwner {
        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        require(success, "Withdrawal failed");
    }

    receive() external payable {}
}