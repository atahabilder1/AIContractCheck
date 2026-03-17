// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    function balanceOf(address owner) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
}

interface IERC3156FlashBorrower {
    function onFlashLoan(address initiator, address token, uint256 amount, uint256 fee, bytes calldata data) external returns (bytes32);
}

interface IERC3156FlashLender {
    function maxFlashLoan(address token) external view returns (uint256);
    function flashFee(address token, uint256 amount) external view returns (uint256);
    function flashLoan(IERC3156FlashBorrower receiver, address token, uint256 amount, bytes calldata data) external returns (bool);
}

contract BasicFlashLender is IERC3156FlashLender {
    IERC20 public immutable token;
    address public owner;
    uint256 public feeBps; // fee in basis points (1/100 of a percent)
    uint256 public constant MAX_BPS = 10_000;
    bytes32 public constant CALLBACK_SUCCESS = keccak256("ERC3156FlashBorrower.onFlashLoan");

    bool private _locked;

    event FlashLoanExecuted(address indexed receiver, uint256 amount, uint256 fee);
    event OwnerUpdated(address indexed oldOwner, address indexed newOwner);
    event FeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event Recovered(address indexed token, address indexed to, uint256 amount);

    modifier nonReentrant() {
        require(!_locked, "Reentrancy");
        _locked = true;
        _;
        _locked = false;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor(address token_, uint256 feeBps_) {
        require(token_ != address(0), "Token zero");
        require(feeBps_ <= MAX_BPS, "Fee too high");
        token = IERC20(token_);
        owner = msg.sender;
        feeBps = feeBps_;
    }

    function setOwner(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Owner zero");
        emit OwnerUpdated(owner, newOwner);
        owner = newOwner;
    }

    function setFeeBps(uint256 newFeeBps) external onlyOwner {
        require(newFeeBps <= MAX_BPS, "Fee too high");
        emit FeeUpdated(feeBps, newFeeBps);
        feeBps = newFeeBps;
    }

    function maxFlashLoan(address token_) external view override returns (uint256) {
        if (token_ != address(token)) return 0;
        return token.balanceOf(address(this));
    }

    function flashFee(address token_, uint256 amount) public view override returns (uint256) {
        require(token_ == address(token), "Unsupported token");
        return (amount * feeBps) / MAX_BPS;
    }

    function flashLoan(IERC3156FlashBorrower receiver, address token_, uint256 amount, bytes calldata data)
        external
        override
        nonReentrant
        returns (bool)
    {
        require(token_ == address(token), "Unsupported token");
        require(amount <= token.balanceOf(address(this)), "Insufficient liquidity");

        uint256 fee = flashFee(token_, amount);

        // Transfer tokens to receiver
        require(token.transfer(address(receiver), amount), "Transfer out failed");

        // Execute callback
        require(
            receiver.onFlashLoan(msg.sender, token_, amount, fee, data) == CALLBACK_SUCCESS,
            "Callback failed"
        );

        // Pull repayment
        uint256 totalOwed = amount + fee;
        require(token.transferFrom(address(receiver), address(this), totalOwed), "Repay failed");

        emit FlashLoanExecuted(address(receiver), amount, fee);
        return true;
    }

    // Recover tokens from the contract (e.g., accrued fees or excess liquidity)
    function recover(address token_, address to, uint256 amount) external onlyOwner {
        require(to != address(0), "To zero");
        require(IERC20(token_).transfer(to, amount), "Recover failed");
        emit Recovered(token_, to, amount);
    }
}