// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Bridge {
    IERC20 public token;
    address payable public ethBridgeAddress;
    uint256 public ethFee;
    uint256 public erc20Fee;

    constructor(IERC20 _token, address payable _ethBridgeAddress, uint256 _ethFee, uint256 _erc20Fee) {
        token = _token;
        ethBridgeAddress = _ethBridgeAddress;
        ethFee = _ethFee;
        erc20Fee = _erc20Fee;
    }

    receive() external payable {}

    function depositETH(uint256 amount) public payable {
        require(msg.value >= amount + ethFee, "Insufficient ETH for transfer");
        (bool success, ) = ethBridgeAddress.call{value: amount}("");
        require(success, "ETH transfer failed");
    }

    function depositERC20(uint256 amount) public {
        IERC20(address(token)).transferFrom(msg.sender, address(this), amount + erc20Fee);
        token.transfer(ethBridgeAddress, amount);
    }
}