// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract CrossChainBridge {
    using SafeERC20 for IERC20;
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    address public immutable validator;
    uint256 public immutable chainId;
    uint64 public nonce;

    mapping(bytes32 => bool) public processedTransfers;

    event Deposit(
        address indexed token,
        address indexed from,
        address indexed to,
        uint256 amount,
        uint256 destChainId,
        uint64 nonce
    );

    event Withdrawal(
        address indexed token,
        address indexed to,
        uint256 amount,
        uint256 srcChainId,
        bytes32 transferId
    );

    event EthDeposit(
        address indexed from,
        address indexed to,
        uint256 amount,
        uint256 destChainId,
        uint64 nonce
    );

    event EthWithdrawal(
        address indexed to,
        uint256 amount,
        uint256 srcChainId,
        bytes32 transferId
    );

    error InvalidSignature();
    error TransferAlreadyProcessed();
    error ZeroAmount();
    error WithdrawalFailed();

    constructor(address _validator) {
        validator = _validator;
        chainId = block.chainid;
    }

    function depositETH(address to, uint256 destChainId) external payable {
        if (msg.value == 0) revert ZeroAmount();
        uint64 current = nonce++;
        emit EthDeposit(msg.sender, to, msg.value, destChainId, current);
    }

    function deposit(
        address token,
        uint256 amount,
        address to,
        uint256 destChainId
    ) external {
        if (amount == 0) revert ZeroAmount();
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        uint64 current = nonce++;
        emit Deposit(token, msg.sender, to, amount, destChainId, current);
    }

    function withdraw(
        address token,
        address to,
        uint256 amount,
        uint256 srcChainId,
        bytes32 srcTransferId,
        bytes calldata signature
    ) external {
        bytes32 transferId = keccak256(
            abi.encodePacked(token, to, amount, srcChainId, chainId, srcTransferId)
        );
        if (processedTransfers[transferId]) revert TransferAlreadyProcessed();

        bytes32 ethSigned = transferId.toEthSignedMessageHash();
        if (ethSigned.recover(signature) != validator) revert InvalidSignature();

        processedTransfers[transferId] = true;
        IERC20(token).safeTransfer(to, amount);
        emit Withdrawal(token, to, amount, srcChainId, transferId);
    }

    function withdrawETH(
        address payable to,
        uint256 amount,
        uint256 srcChainId,
        bytes32 srcTransferId,
        bytes calldata signature
    ) external {
        bytes32 transferId = keccak256(
            abi.encodePacked(address(0), to, amount, srcChainId, chainId, srcTransferId)
        );
        if (processedTransfers[transferId]) revert TransferAlreadyProcessed();

        bytes32 ethSigned = transferId.toEthSignedMessageHash();
        if (ethSigned.recover(signature) != validator) revert InvalidSignature();

        processedTransfers[transferId] = true;
        (bool success, ) = to.call{value: amount}("");
        if (!success) revert WithdrawalFailed();
        emit EthWithdrawal(to, amount, srcChainId, transferId);
    }

    receive() external payable {}
}