// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract WrappedTokenBridge is ERC20, AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;

    bytes32 public constant BRIDGE_ROLE = keccak256("BRIDGE_ROLE");
    bytes32 public constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");

    IERC20 public immutable canonicalToken;
    bool public immutable isCanonicalChain;

    struct ChainDeposit {
        uint256 totalDeposited;
        uint256 totalWithdrawn;
        uint256 mintCap;
        bool enabled;
    }

    mapping(uint256 => ChainDeposit) public chainDeposits;
    uint256[] public supportedChains;
    mapping(uint256 => bool) private chainExists;

    uint256 public totalBridgedOut;
    uint256 public totalBridgedIn;

    event Deposited(address indexed user, uint256 amount, uint256 indexed destChainId, bytes32 indexed depositId);
    event Withdrawn(address indexed user, uint256 amount, uint256 indexed sourceChainId, bytes32 indexed depositId);
    event BridgeMinted(address indexed recipient, uint256 amount, uint256 indexed sourceChainId, bytes32 indexed depositId);
    event BridgeBurned(address indexed user, uint256 amount, uint256 indexed destChainId, bytes32 indexed depositId);
    event ChainAdded(uint256 indexed chainId, uint256 mintCap);
    event ChainToggled(uint256 indexed chainId, bool enabled);
    event MintCapUpdated(uint256 indexed chainId, uint256 newCap);

    error ChainNotSupported(uint256 chainId);
    error ChainDisabled(uint256 chainId);
    error MintCapExceeded(uint256 chainId, uint256 requested, uint256 remaining);
    error SupplyInvariantViolation(uint256 expected, uint256 actual);
    error ZeroAmount();
    error ChainAlreadyExists(uint256 chainId);
    error NotCanonicalChain();
    error NotBridgedChain();

    constructor(
        string memory name_,
        string memory symbol_,
        address canonicalToken_,
        bool isCanonicalChain_,
        address admin
    ) ERC20(name_, symbol_) {
        canonicalToken = IERC20(canonicalToken_);
        isCanonicalChain = isCanonicalChain_;
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(GOVERNOR_ROLE, admin);
    }

    function addChain(uint256 chainId, uint256 mintCap) external onlyRole(GOVERNOR_ROLE) {
        if (chainExists[chainId]) revert ChainAlreadyExists(chainId);
        chainExists[chainId] = true;
        supportedChains.push(chainId);
        chainDeposits[chainId] = ChainDeposit({
            totalDeposited: 0,
            totalWithdrawn: 0,
            mintCap: mintCap,
            enabled: true
        });
        emit ChainAdded(chainId, mintCap);
    }

    function toggleChain(uint256 chainId, bool enabled) external onlyRole(GOVERNOR_ROLE) {
        _requireChainSupported(chainId);
        chainDeposits[chainId].enabled = enabled;
        emit ChainToggled(chainId, enabled);
    }

    function setMintCap(uint256 chainId, uint256 newCap) external onlyRole(GOVERNOR_ROLE) {
        _requireChainSupported(chainId);
        chainDeposits[chainId].mintCap = newCap;
        emit MintCapUpdated(chainId, newCap);
    }

    /// @notice Lock canonical tokens on the home chain to bridge out
    function deposit(uint256 amount, uint256 destChainId) external nonReentrant {
        if (!isCanonicalChain) revert NotCanonicalChain();
        if (amount == 0) revert ZeroAmount();
        _requireChainActive(destChainId);

        canonicalToken.safeTransferFrom(msg.sender, address(this), amount);

        chainDeposits[destChainId].totalDeposited += amount;
        totalBridgedOut += amount;

        bytes32 depositId = _generateId(msg.sender, amount, destChainId, block.number);

        _checkCanonicalInvariant();

        emit Deposited(msg.sender, amount, destChainId, depositId);
    }

    /// @notice Release canonical tokens on home chain when bridging back
    function withdraw(address recipient, uint256 amount, uint256 sourceChainId, bytes32 depositId)
        external
        nonReentrant
        onlyRole(BRIDGE_ROLE)
    {
        if (!isCanonicalChain) revert NotCanonicalChain();
        if (amount == 0) revert ZeroAmount();
        _requireChainActive(sourceChainId);

        chainDeposits[sourceChainId].totalWithdrawn += amount;
        totalBridgedIn += amount;

        canonicalToken.safeTransfer(recipient, amount);

        _checkCanonicalInvariant();

        emit Withdrawn(recipient, amount, sourceChainId, depositId);
    }

    /// @notice Mint bridged (wrapped) tokens on a non-canonical chain
    function bridgeMint(address recipient, uint256 amount, uint256 sourceChainId, bytes32 depositId)
        external
        nonReentrant
        onlyRole(BRIDGE_ROLE)
    {
        if (isCanonicalChain) revert NotBridgedChain();
        if (amount == 0) revert ZeroAmount();
        _requireChainActive(sourceChainId);

        ChainDeposit storage cd = chainDeposits[sourceChainId];
        uint256 netMinted = cd.totalDeposited - cd.totalWithdrawn;
        if (netMinted + amount > cd.mintCap) {
            revert MintCapExceeded(sourceChainId, amount, cd.mintCap - netMinted);
        }

        cd.totalDeposited += amount;
        totalBridgedIn += amount;

        _mint(recipient, amount);

        _checkBridgedInvariant();

        emit BridgeMinted(recipient, amount, sourceChainId, depositId);
    }

    /// @notice Burn bridged tokens to bridge back to canonical chain
    function bridgeBurn(uint256 amount, uint256 destChainId) external nonReentrant {
        if (isCanonicalChain) revert NotBridgedChain();
        if (amount == 0) revert ZeroAmount();
        _requireChainActive(destChainId);

        _burn(msg.sender, amount);

        chainDeposits[destChainId].totalWithdrawn += amount;
        totalBridgedOut += amount;

        bytes32 depositId = _generateId(msg.sender, amount, destChainId, block.number);

        _checkBridgedInvariant();

        emit BridgeBurned(msg.sender, amount, destChainId, depositId);
    }

    function getNetFlow(uint256 chainId) external view returns (int256) {
        _requireChainSupported(chainId);
        ChainDeposit storage cd = chainDeposits[chainId];
        return int256(cd.totalDeposited) - int256(cd.totalWithdrawn);
    }

    function getSupportedChains() external view returns (uint256[] memory) {
        return supportedChains;
    }

    function decimals() public view override returns (uint8) {
        return 18;
    }

    /// @dev On canonical chain: locked tokens >= net bridged out
    function _checkCanonicalInvariant() internal view {
        uint256 locked = canonicalToken.balanceOf(address(this));
        uint256 netOut = totalBridgedOut > totalBridgedIn ? totalBridgedOut - totalBridgedIn : 0;
        if (locked < netOut) {
            revert SupplyInvariantViolation(netOut, locked);
        }
    }

    /// @dev On bridged chain: total supply == net bridged in
    function _checkBridgedInvariant() internal view {
        uint256 supply = totalSupply();
        uint256 netIn = totalBridgedIn > totalBridgedOut ? totalBridgedIn - totalBridgedOut : 0;
        if (supply != netIn) {
            revert SupplyInvariantViolation(netIn, supply);
        }
    }

    function _requireChainSupported(uint256 chainId) internal view {
        if (!chainExists[chainId]) revert ChainNotSupported(chainId);
    }

    function _requireChainActive(uint256 chainId) internal view {
        _requireChainSupported(chainId);
        if (!chainDeposits[chainId].enabled) revert ChainDisabled(chainId);
    }

    function _generateId(address user, uint256 amount, uint256 chainId, uint256 blockNum)
        internal
        view
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(user, amount, chainId, blockNum, block.chainid, block.timestamp));
    }
}