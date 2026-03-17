// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function transfer(address,uint256) external returns (bool);
}

interface IERC3156FlashBorrower {
    function onFlashLoan(address initiator,address token,uint256 amount,uint256 fee,bytes calldata data) external returns (bytes32);
}

interface IERC3156FlashLender {
    function maxFlashLoan(address token) external view returns (uint256);
    function flashFee(address token,uint256 amount) external view returns (uint256);
    function flashLoan(IERC3156FlashBorrower receiver,address token,uint256 amount,bytes calldata data) external returns (bool);
}

error TokenNotSupported();
error TransferFailed();
error CallbackFailed();
error InsufficientRepayment();

contract FlashLender is IERC3156FlashLender {
    IERC20 public immutable token;
    uint256 public immutable feeBps;
    bytes32 private constant CALLBACK_SUCCESS = keccak256("ERC3156FlashBorrower.onFlashLoan");

    constructor(IERC20 token_, uint256 feeBps_) {
        token = token_;
        feeBps = feeBps_;
    }

    function maxFlashLoan(address token_) external view returns (uint256) {
        return token_ == address(token) ? token.balanceOf(address(this)) : 0;
    }

    function flashFee(address token_, uint256 amount) public view returns (uint256 fee) {
        if (token_ != address(token)) revert TokenNotSupported();
        unchecked {
            fee = (amount * feeBps) / 10000;
        }
    }

    function flashLoan(IERC3156FlashBorrower receiver, address token_, uint256 amount, bytes calldata data) external returns (bool) {
        if (token_ != address(token)) revert TokenNotSupported();

        uint256 fee;
        unchecked { fee = (amount * feeBps) / 10000; }

        uint256 balBefore = token.balanceOf(address(this));
        _safeTransfer(address(token), address(receiver), amount);

        if (receiver.onFlashLoan(msg.sender, token_, amount, fee, data) != CALLBACK_SUCCESS) revert CallbackFailed();

        if (token.balanceOf(address(this)) < balBefore + fee) revert InsufficientRepayment();
        return true;
    }

    function _safeTransfer(address token_, address to, uint256 value) private {
        (bool ok, bytes memory data) = token_.call(abi.encodeWithSelector(0xa9059cbb, to, value));
        if (!ok || (data.length != 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }
}