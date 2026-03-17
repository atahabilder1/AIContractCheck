// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract EmergencyERC1155 is ERC1155, ERC1155Pausable, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    event EmergencyWithdrawETH(address indexed to, uint256 amount);
    event EmergencySweepERC20(address indexed token, address indexed to, uint256 amount);
    event URIUpdated(string newURI);

    constructor(string memory initialURI, address initialOwner) ERC1155(initialURI) Ownable(initialOwner) {}

    // Minting (admin)
    function mint(address to, uint256 id, uint256 amount, bytes memory data) external onlyOwner whenNotPaused {
        _mint(to, id, amount, data);
    }

    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        external
        onlyOwner
        whenNotPaused
    {
        _mintBatch(to, ids, amounts, data);
    }

    // Burning (holder or approved)
    function burn(address from, uint256 id, uint256 amount) external whenNotPaused {
        require(from == _msgSender() || isApprovedForAll(from, _msgSender()), "Not owner nor approved");
        _burn(from, id, amount);
    }

    function burnBatch(address from, uint256[] memory ids, uint256[] memory amounts) external whenNotPaused {
        require(from == _msgSender() || isApprovedForAll(from, _msgSender()), "Not owner nor approved");
        _burnBatch(from, ids, amounts);
    }

    // URI management (admin)
    function setURI(string memory newuri) external onlyOwner {
        _setURI(newuri);
        emit URIUpdated(newuri);
    }

    // Pause controls (admin)
    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    // Emergency withdraws (admin)
    receive() external payable {}

    function emergencyWithdrawETH(address payable to) public onlyOwner nonReentrant {
        require(to != address(0), "Invalid recipient");
        uint256 bal = address(this).balance;
        if (bal > 0) {
            Address.sendValue(to, bal);
            emit EmergencyWithdrawETH(to, bal);
        }
    }

    function emergencySweepERC20(IERC20 token, address to) public onlyOwner nonReentrant {
        require(to != address(0), "Invalid recipient");
        uint256 bal = token.balanceOf(address(this));
        if (bal > 0) {
            token.safeTransfer(to, bal);
            emit EmergencySweepERC20(address(token), to, bal);
        }
    }

    function emergencyWithdrawAll(address payable to, IERC20[] calldata tokens) external onlyOwner nonReentrant {
        emergencyWithdrawETH(to);
        for (uint256 i = 0; i < tokens.length; i++) {
            emergencySweepERC20(tokens[i], to);
        }
    }

    // Overrides
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC1155) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}