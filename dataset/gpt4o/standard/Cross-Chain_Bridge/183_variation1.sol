// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
}

contract Bridge {
    address public owner;
    uint256 public nativeFee;
    uint256 public erc20Fee;

    event TransferToChain(address indexed sender, address indexed recipient, uint256 amount, string destinationChain);
    event TransferToChainERC20(address indexed sender, address indexed recipient, uint256 amount, string destinationChain, address token);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not contract owner");
        _;
    }

    constructor(uint256 _nativeFee, uint256 _erc20Fee) {
        owner = msg.sender;
        nativeFee = _nativeFee;
        erc20Fee = _erc20Fee;
    }

    function setFees(uint256 _nativeFee, uint256 _erc20Fee) external onlyOwner {
        nativeFee = _nativeFee;
        erc20Fee = _erc20Fee;
    }

    function transferToChain(address payable recipient, string memory destinationChain) external payable {
        require(msg.value > nativeFee, "Insufficient ETH for fees");
        uint256 amountToTransfer = msg.value - nativeFee;
        recipient.transfer(amountToTransfer);
        emit TransferToChain(msg.sender, recipient, amountToTransfer, destinationChain);
    }

    function transferToChainERC20(address token, uint256 amount, address recipient, string memory destinationChain) external {
        require(amount > erc20Fee, "Insufficient token amount for fees");
        IERC20 erc20 = IERC20(token);
        uint256 allowance = erc20.allowance(msg.sender, address(this));
        require(allowance >= amount, "Allowance not sufficient");
        uint256 amountToTransfer = amount - erc20Fee;
        require(erc20.transferFrom(msg.sender, address(this), amountToTransfer), "Transfer failed");
        require(erc20.transfer(owner, erc20Fee), "Fee transfer failed");
        emit TransferToChainERC20(msg.sender, recipient, amountToTransfer, destinationChain, token);
    }

    function withdrawERC20(address token, uint256 amount) external onlyOwner {
        IERC20 erc20 = IERC20(token);
        require(erc20.balanceOf(address(this)) >= amount, "Insufficient balance");
        require(erc20.transfer(msg.sender, amount), "Transfer failed");
    }

    function withdrawETH(uint256 amount) external onlyOwner {
        require(address(this).balance >= amount, "Insufficient balance");
        payable(owner).transfer(amount);
    }
}