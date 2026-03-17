// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MultiToken is ERC1155, Ownable {
    bool public operationsPaused = false;

    constructor() ERC1155("https://example.com") {}

    function pauseOperations() external onlyOwner {
        operationsPaused = true;
    }

    function resumeOperations() external onlyOwner {
        operationsPaused = false;
    }

    function emergencyWithdraw(address payable recipient, uint256 amount) external onlyOwner {
        require(!operationsPaused, "Operations are paused");
        _safeTransferETH(recipient, amount);
    }
}