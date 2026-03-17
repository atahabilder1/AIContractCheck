// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract LiquidStakingToken is ERC20, Ownable {
    using SafeERC20 for IERC20Metadata;

    error ZeroAmount();
    error ZeroShares();
    error InvalidReceiver();
    error RecoverUnderlyingNotAllowed();
    error Reentrancy();

    IERC20Metadata public immutable stakingToken;
    uint8 private immutable _underlyingDecimals;

    uint256 private _locked;

    event Stake(address indexed caller, address indexed receiver, uint256 assets, uint256 shares);
    event Unstake(address indexed caller, address indexed receiver, uint256 assets, uint256 shares);
    event Donate(address indexed caller, uint256 assets);

    modifier nonReentrant() {
        if (_locked == 1) revert Reentrancy();
        _locked = 1;
        _;
        _locked = 0;
    }

    constructor(address underlying, string memory name_, string memory symbol_) ERC20(name_, symbol_) {
        require(underlying != address(0), "UNDERLYING_ZERO");
        stakingToken = IERC20Metadata(underlying);
        _underlyingDecimals = IERC20Metadata(underlying).decimals();
    }

    function decimals() public view override returns (uint8) {
        return _underlyingDecimals;
    }

    // View functions
    function totalAssets() public view returns (uint256) {
        return stakingToken.balanceOf(address(this));
    }

    function convertToShares(uint256 assets) public view returns (uint256) {
        uint256 supply = totalSupply();
        uint256 assetsCached = totalAssets();
        if (supply == 0 || assetsCached == 0) {
            return assets;
        }
        return Math.mulDiv(assets, supply, assetsCached);
    }

    function convertToAssets(uint256 shares) public view returns (uint256) {
        uint256 supply = totalSupply();
        uint256 assetsCached = totalAssets();
        if (supply == 0) {
            return 0;
        }
        return Math.mulDiv(shares, assetsCached, supply);
    }

    function previewStake(uint256 assets) external view returns (uint256) {
        return convertToShares(assets);
    }

    function previewUnstake(uint256 shares) external view returns (uint256) {
        return convertToAssets(shares);
    }

    // Core functions
    function stake(uint256 assets, address receiver) external nonReentrant returns (uint256 shares) {
        if (assets == 0) revert ZeroAmount();
        if (receiver == address(0)) revert InvalidReceiver();

        uint256 supply = totalSupply();
        uint256 assetsBefore = totalAssets();

        stakingToken.safeTransferFrom(msg.sender, address(this), assets);

        uint256 received = totalAssets() - assetsBefore;
        if (received == 0) revert ZeroAmount();

        shares = (supply == 0 || assetsBefore == 0)
            ? received
            : Math.mulDiv(received, supply, assetsBefore);

        if (shares == 0) revert ZeroShares();

        _mint(receiver, shares);

        emit Stake(msg.sender, receiver, received, shares);
    }

    function unstake(uint256 shares, address receiver) external nonReentrant returns (uint256 assets) {
        if (shares == 0) revert ZeroShares();
        if (receiver == address(0)) revert InvalidReceiver();

        assets = convertToAssets(shares);
        if (assets == 0) revert ZeroAmount();

        _burn(msg.sender, shares);
        stakingToken.safeTransfer(receiver, assets);

        emit Unstake(msg.sender, receiver, assets, shares);
    }

    // Optional: donate rewards to raise the exchange rate (anyone can add rewards)
    function donate(uint256 assets) external nonReentrant {
        if (assets == 0) revert ZeroAmount();
        uint256 beforeBal = totalAssets();
        stakingToken.safeTransferFrom(msg.sender, address(this), assets);
        uint256 received = totalAssets() - beforeBal;
        if (received == 0) revert ZeroAmount();
        emit Donate(msg.sender, received);
    }

    // Admin recover of tokens mistakenly sent (excluding underlying stakingToken)
    function recoverERC20(address token, address to, uint256 amount) external onlyOwner nonReentrant {
        if (token == address(stakingToken)) revert RecoverUnderlyingNotAllowed();
        IERC20Metadata(token).safeTransfer(to, amount);
    }

    // Prevent accidental ETH transfers
    receive() external payable {
        revert("NO_ETH");
    }

    fallback() external payable {
        revert("NO_ETH");
    }
}