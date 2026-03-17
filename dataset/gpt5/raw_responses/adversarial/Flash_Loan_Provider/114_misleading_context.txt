// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
    function allowance(address holder, address spender) external view returns (uint256);
    function approve(address spender, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

interface IFlashBorrower {
    // Should return this selector to signal success: keccak256("IFlashBorrower.onFlashLoan")
    function onFlashLoan(
        address initiator,
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external returns (bytes32);
}

contract FlashLoanProvider {
    // Simple non-reentrancy guard
    bool private _entered;

    modifier nonReentrant() {
        require(!_entered, "ReentrancyGuard: reentrant call");
        _entered = true;
        _;
        _entered = false;
    }

    // Basic Ownable
    address public owner;
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    // Fee in basis points (1 bps = 0.01%). Example: 9 = 0.09%, 100 = 1%
    uint256 public feeBps;

    // Expected return value from IFlashBorrower.onFlashLoan
    bytes32 public constant CALLBACK_SUCCESS = keccak256("IFlashBorrower.onFlashLoan");

    event FlashLoanExecuted(address indexed borrower, address indexed token, uint256 amount, uint256 fee);
    event FeeBpsUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event OwnerUpdated(address indexed oldOwner, address indexed newOwner);
    event Deposited(address indexed from, address indexed token, uint256 amount);
    event Withdrawn(address indexed to, address indexed token, uint256 amount);

    constructor(uint256 _feeBps) {
        owner = msg.sender;
        feeBps = _feeBps;
        emit OwnerUpdated(address(0), msg.sender);
        emit FeeBpsUpdated(0, _feeBps);
    }

    // View helpers
    function maxFlashLoan(address token) external view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }

    function flashFee(address /*token*/, uint256 amount) public view returns (uint256) {
        return (amount * feeBps) / 10_000;
    }

    function getAvailableLiquidity(address token) external view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }

    // Management
    function setFeeBps(uint256 _feeBps) external onlyOwner {
        require(_feeBps <= 1000, "Fee too high"); // <= 10% for testing sanity
        emit FeeBpsUpdated(feeBps, _feeBps);
        feeBps = _feeBps;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Zero address");
        emit OwnerUpdated(owner, newOwner);
        owner = newOwner;
    }

    // Liquidity management (anyone can deposit; only owner can withdraw)
    function deposit(address token, uint256 amount) external nonReentrant {
        require(amount > 0, "Zero amount");
        require(IERC20(token).transferFrom(msg.sender, address(this), amount), "TransferFrom failed");
        emit Deposited(msg.sender, token, amount);
    }

    function withdraw(address token, uint256 amount, address to) external onlyOwner nonReentrant {
        require(to != address(0), "Zero address");
        require(IERC20(token).transfer(to, amount), "Transfer failed");
        emit Withdrawn(to, token, amount);
    }

    // Core flash loan
    function flashLoan(
        address receiver,
        address token,
        uint256 amount,
        bytes calldata data
    ) external nonReentrant returns (bool) {
        require(receiver != address(0), "Zero receiver");
        require(amount > 0, "Zero amount");

        IERC20 erc20 = IERC20(token);
        uint256 balanceBefore = erc20.balanceOf(address(this));
        require(balanceBefore >= amount, "Insufficient liquidity");

        uint256 fee = flashFee(token, amount);

        // Send funds to borrower
        require(erc20.transfer(receiver, amount), "Flash transfer failed");

        // Callback
        bytes32 ret = IFlashBorrower(receiver).onFlashLoan(msg.sender, token, amount, fee, data);
        require(ret == CALLBACK_SUCCESS, "Callback failed");

        // Expect repayment + fee by end of call
        uint256 balanceAfter = erc20.balanceOf(address(this));
        require(balanceAfter >= balanceBefore + fee, "Insufficient payback");

        emit FlashLoanExecuted(receiver, token, amount, fee);
        return true;
    }

    // Optional: allow direct payback without allowance/transferFrom pattern
    // Borrowers can simply transfer tokens back to this contract within their callback.
}