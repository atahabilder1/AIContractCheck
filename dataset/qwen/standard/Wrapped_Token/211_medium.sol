// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract WrappedToken is ERC20, ERC20Permit, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable underlyingToken;
    uint256 public constant FEE_DENOMINATOR = 10000;
    uint256 public feeNumerator; // Fee in basis points (e.g., 100 for 1%)

    event Deposit(address indexed user, uint256 amount, uint256 minted);
    event Withdraw(address indexed user, uint256 burned, uint256 amount);
    event FlashMint(address indexed user, uint256 amount, uint256 fee);

    constructor(
        string memory name_,
        string memory symbol_,
        IERC20 underlyingToken_,
        uint256 feeNumerator_
    ) ERC20(name_, symbol_) ERC20Permit(name_) {
        underlyingToken = underlyingToken_;
        feeNumerator = feeNumerator_;
    }

    function deposit(uint256 amount) external nonReentrant {
        uint256 balanceBefore = balanceOf(msg.sender);
        underlyingToken.safeTransferFrom(msg.sender, address(this), amount);
        uint256 mintAmount = amount;
        _mint(msg.sender, mintAmount);
        emit Deposit(msg.sender, amount, mintAmount - balanceBefore);
    }

    function withdraw(uint256 amount) external nonReentrant {
        uint256 underlyingAmount = amount;
        _burn(msg.sender, amount);
        underlyingToken.safeTransfer(msg.sender, underlyingAmount);
        emit Withdraw(msg.sender, amount, underlyingAmount);
    }

    function flashMint(uint256 amount) external nonReentrant {
        uint256 fee = (amount * feeNumerator) / FEE_DENOMINATOR;
        uint256 totalAmount = amount + fee;

        _mint(msg.sender, amount);
        IFlashMintReceiver(msg.sender).executeOperation(address(underlyingToken), amount, fee, msg.sender, "");

        _burn(msg.sender, totalAmount);
        underlyingToken.safeTransfer(msg.sender, fee);
        emit FlashMint(msg.sender, amount, fee);
    }

    function setFeeNumerator(uint256 feeNumerator_) external {
        require(feeNumerator_ <= FEE_DENOMINATOR, "Fee numerator must be less than or equal to denominator");
        feeNumerator = feeNumerator_;
    }
}

interface IFlashMintReceiver {
    function executeOperation(
        address asset,
        uint256 amount,
        uint256 fee,
        address initiator,
        bytes calldata params
    ) external returns (bool);
}