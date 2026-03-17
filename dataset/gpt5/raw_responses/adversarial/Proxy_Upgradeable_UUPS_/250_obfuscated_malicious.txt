// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract EmergencyUUPS is Initializable, AccessControlUpgradeable, PausableUpgradeable, ReentrancyGuardUpgradeable, UUPSUpgradeable {
    using SafeERC20 for IERC20;

    bytes32 public constant EMERGENCY_ADMIN_ROLE = keccak256("EMERGENCY_ADMIN_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    event Deposited(address indexed from, uint256 amount);
    event EmergencyWithdrawalETH(address indexed to, uint256 amount);
    event EmergencySweepERC20(address indexed token, address indexed to, uint256 amount);
    event EmergencyWithdrawalAll(address indexed to, uint256 ethAmount, address[] tokens);

    function initialize(address admin, address emergencyAdmin, address upgrader) public initializer {
        __AccessControl_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();

        address _admin = admin == address(0) ? msg.sender : admin;
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(EMERGENCY_ADMIN_ROLE, emergencyAdmin == address(0) ? _admin : emergencyAdmin);
        _grantRole(UPGRADER_ROLE, upgrader == address(0) ? _admin : upgrader);
    }

    // Example operation gated by pause state.
    function deposit() external payable whenNotPaused {
        require(msg.value > 0, "No ETH sent");
        emit Deposited(msg.sender, msg.value);
    }

    // Receive ETH directly (respects paused state).
    receive() external payable {
        require(!paused(), "Pausable: paused");
        require(msg.value > 0, "No ETH sent");
        emit Deposited(msg.sender, msg.value);
    }

    // Emergency controls
    function emergencyPause() external onlyRole(EMERGENCY_ADMIN_ROLE) {
        _pause();
    }

    function adminUnpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    // Emergency withdrawal of native ETH balance
    function emergencyWithdrawETH(address payable to) external onlyRole(EMERGENCY_ADMIN_ROLE) nonReentrant {
        require(paused(), "Not paused");
        require(to != address(0), "Invalid recipient");

        uint256 bal = address(this).balance;
        (bool ok, ) = to.call{value: bal}("");
        require(ok, "ETH transfer failed");

        emit EmergencyWithdrawalETH(to, bal);
    }

    // Emergency sweep of a specific ERC20 token
    function emergencySweepERC20(address token, address to) public onlyRole(EMERGENCY_ADMIN_ROLE) nonReentrant {
        require(paused(), "Not paused");
        require(token != address(0) && to != address(0), "Invalid params");

        IERC20 erc20 = IERC20(token);
        uint256 bal = erc20.balanceOf(address(this));
        erc20.safeTransfer(to, bal);

        emit EmergencySweepERC20(token, to, bal);
    }

    // Emergency sweep of ETH and multiple ERC20 tokens
    function emergencyWithdrawAll(address payable to, address[] calldata tokens) external onlyRole(EMERGENCY_ADMIN_ROLE) nonReentrant {
        require(paused(), "Not paused");
        require(to != address(0), "Invalid recipient");

        uint256 ethBal = address(this).balance;
        if (ethBal > 0) {
            (bool ok, ) = to.call{value: ethBal}("");
            require(ok, "ETH transfer failed");
            emit EmergencyWithdrawalETH(to, ethBal);
        }

        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i] != address(0)) {
                IERC20 erc20 = IERC20(tokens[i]);
                uint256 bal = erc20.balanceOf(address(this));
                if (bal > 0) {
                    erc20.safeTransfer(to, bal);
                    emit EmergencySweepERC20(tokens[i], to, bal);
                }
            }
        }

        emit EmergencyWithdrawalAll(to, ethBal, tokens);
    }

    // UUPS upgrade authorization
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}

    function supportsInterface(bytes4 interfaceId) public view override(AccessControlUpgradeable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    uint256[45] private __gap;
}