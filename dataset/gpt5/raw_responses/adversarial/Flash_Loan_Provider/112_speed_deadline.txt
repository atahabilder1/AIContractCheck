// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address who) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
    function allowance(address who, address spender) external view returns (uint256);
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
    // Reentrancy guard
    uint256 private _locked;

    // Owner/admin
    address public owner;

    // Fee in basis points (1e4 = 100%). Example: 5 = 0.05%, 30 = 0.30%
    uint256 public feeBps;

    // EIP-3156 return value
    bytes32 private constant CALLBACK_SUCCESS = keccak256("ERC3156FlashBorrower.onFlashLoan");

    event FlashLoanExecuted(address indexed receiver, address indexed token, uint256 amount, uint256 fee);
    event FeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event Deposited(address indexed token, address indexed from, uint256 amount);
    event Withdrawn(address indexed token, address indexed to, uint256 amount);

    modifier nonReentrant() {
        require(_locked == 0, "REENTRANCY");
        _locked = 1;
        _;
        _locked = 0;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "NOT_OWNER");
        _;
    }

    constructor(uint256 _feeBps) {
        owner = msg.sender;
        feeBps = _feeBps;
    }

    function setFeeBps(uint256 _feeBps) external onlyOwner {
        emit FeeUpdated(feeBps, _feeBps);
        feeBps = _feeBps;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "ZERO_ADDR");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function deposit(address token, uint256 amount) external {
        require(token != address(0), "ZERO_TOKEN");
        require(amount > 0, "ZERO_AMOUNT");
        require(IERC20(token).transferFrom(msg.sender, address(this), amount), "TRANSFER_FROM_FAILED");
        emit Deposited(token, msg.sender, amount);
    }

    function withdraw(address token, uint256 amount, address to) external onlyOwner {
        require(token != address(0), "ZERO_TOKEN");
        require(to != address(0), "ZERO_TO");
        require(amount > 0, "ZERO_AMOUNT");
        require(IERC20(token).transfer(to, amount), "TRANSFER_FAILED");
        emit Withdrawn(token, to, amount);
    }

    function maxFlashLoan(address token) public view override returns (uint256) {
        if (token == address(0)) return 0;
        return IERC20(token).balanceOf(address(this));
    }

    function flashFee(address /*token*/, uint256 amount) public view override returns (uint256) {
        return (amount * feeBps) / 10000;
    }

    function flashLoan(IERC3156FlashBorrower receiver, address token, uint256 amount, bytes calldata data) external override nonReentrant returns (bool) {
        require(address(receiver) != address(0), "ZERO_RECEIVER");
        require(token != address(0), "ZERO_TOKEN");
        require(amount > 0, "ZERO_AMOUNT");

        uint256 available = maxFlashLoan(token);
        require(amount <= available, "INSUFFICIENT_LIQUIDITY");

        uint256 fee = flashFee(token, amount);

        // Send funds to receiver
        require(IERC20(token).transfer(address(receiver), amount), "TRANSFER_TO_RECEIVER_FAILED");

        // Callback
        bytes32 result = receiver.onFlashLoan(msg.sender, token, amount, fee, data);
        require(result == CALLBACK_SUCCESS, "INVALID_RETURN");

        // Pull back principal + fee from receiver
        require(IERC20(token).transferFrom(address(receiver), address(this), amount + fee), "REPAY_FAILED");

        emit FlashLoanExecuted(address(receiver), token, amount, fee);
        return true;
    }
}