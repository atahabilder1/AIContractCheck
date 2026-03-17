// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address who) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
    function allowance(address owner_, address spender) external view returns (uint256);
    function approve(address spender, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

interface IERC3156FlashBorrower {
    function onFlashLoan(address initiator, address token, uint256 amount, uint256 fee, bytes calldata data) external returns (bytes32);
}

interface IERC3156FlashLender {
    function maxFlashLoan(address token) external view returns (uint256);
    function flashFee(address token, uint256 amount) external view returns (uint256);
    function flashLoan(IERC3156FlashBorrower receiver, address token, uint256 amount, bytes calldata data) external returns (bool);
}

contract FlashLoanProvider is IERC3156FlashLender {
    // keccak256("ERC3156FlashBorrower.onFlashLoan")
    bytes32 public constant FLASH_CALLBACK_SUCCESS = 0x0dcd7a6c6f8a0d7330a5c9e2cfb0e0f3ee9f3a7d3a3e0e9c1f4b0b88d7e5d7a0;

    address public owner;
    uint256 public feeBps; // fee in basis points (1 bps = 0.01%). e.g., 9 => 0.09%
    bool public paused;

    uint256 private _reentrancyStatus; // 1 = entered, 2 = not entered

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event FeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event Paused(address indexed account);
    event Unpaused(address indexed account);
    event Deposited(address indexed token, address indexed from, uint256 amount);
    event Withdrawn(address indexed token, address indexed to, uint256 amount);
    event FlashLoanExecuted(address indexed receiver, address indexed token, uint256 amount, uint256 fee, address initiator);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "Paused");
        _;
    }

    modifier nonReentrant() {
        require(_reentrancyStatus != 1, "Reentrancy");
        _reentrancyStatus = 1;
        _;
        _reentrancyStatus = 2;
    }

    constructor(uint256 feeBps_) {
        owner = msg.sender;
        feeBps = feeBps_;
        _reentrancyStatus = 2;
        emit OwnershipTransferred(address(0), msg.sender);
        emit FeeUpdated(0, feeBps_);
    }

    // IERC3156FlashLender

    function maxFlashLoan(address token) external view override returns (uint256) {
        return _tokenBalance(IERC20(token));
    }

    function flashFee(address /*token*/, uint256 amount) public view override returns (uint256) {
        return (amount * feeBps) / 10_000;
    }

    function flashLoan(IERC3156FlashBorrower receiver, address token, uint256 amount, bytes calldata data)
        external
        override
        whenNotPaused
        nonReentrant
        returns (bool)
    {
        IERC20 erc20 = IERC20(token);
        uint256 available = _tokenBalance(erc20);
        require(amount > 0, "Zero amount");
        require(available >= amount, "Insufficient liquidity");

        uint256 fee = flashFee(token, amount);
        uint256 balanceBefore = available;

        _safeTransfer(erc20, address(receiver), amount);

        bytes32 ret = receiver.onFlashLoan(msg.sender, token, amount, fee, data);
        require(ret == FLASH_CALLBACK_SUCCESS, "Callback failed");

        // Borrower must have approved the lender to pull amount + fee
        _safeTransferFrom(erc20, address(receiver), address(this), amount + fee);

        // Sanity check: balance increased by at least the fee
        uint256 balanceAfter = _tokenBalance(erc20);
        require(balanceAfter >= balanceBefore + fee, "Insufficient repayment");

        emit FlashLoanExecuted(address(receiver), token, amount, fee, msg.sender);
        return true;
    }

    // Admin

    function setFeeBps(uint256 newFeeBps) external onlyOwner {
        require(newFeeBps <= 10_000, "Fee too high");
        uint256 old = feeBps;
        feeBps = newFeeBps;
        emit FeeUpdated(old, newFeeBps);
    }

    function pause() external onlyOwner {
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOwner {
        paused = false;
        emit Unpaused(msg.sender);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Zero addr");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    // Liquidity management

    function deposit(address token, uint256 amount) external whenNotPaused nonReentrant {
        require(amount > 0, "Zero amount");
        _safeTransferFrom(IERC20(token), msg.sender, address(this), amount);
        emit Deposited(token, msg.sender, amount);
    }

    function withdraw(address token, uint256 amount, address to) external onlyOwner nonReentrant {
        require(to != address(0), "Zero addr");
        _safeTransfer(IERC20(token), to, amount);
        emit Withdrawn(token, to, amount);
    }

    // Internal helpers

    function _tokenBalance(IERC20 token) internal view returns (uint256) {
        return token.balanceOf(address(this));
    }

    function _safeTransfer(IERC20 token, address to, uint256 value) internal {
        bytes memory data = abi.encodeWithSelector(token.transfer.selector, to, value);
        _callOptionalReturn(address(token), data);
    }

    function _safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        bytes memory data = abi.encodeWithSelector(token.transferFrom.selector, from, to, value);
        _callOptionalReturn(address(token), data);
    }

    function _callOptionalReturn(address token, bytes memory data) private {
        (bool success, bytes memory returndata) = token.call(data);
        require(success, "Token call failed");
        if (returndata.length > 0) {
            require(abi.decode(returndata, (bool)), "ERC20 op failed");
        }
    }
}