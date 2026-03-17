// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

interface IERC3156FlashBorrower {
    function onFlashLoan(
        address initiator,
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external returns (bytes32);
}

interface IERC3156FlashLender {
    function maxFlashLoan(address token) external view returns (uint256);
    function flashFee(address token, uint256 amount) external view returns (uint256);
    function flashLoan(
        IERC3156FlashBorrower receiver,
        address token,
        uint256 amount,
        bytes calldata data
    ) external returns (bool);
}

contract FlashLoanProvider is IERC3156FlashLender {
    // Reentrancy guard
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;

    // EIP-3156 required success selector
    bytes32 public constant CALLBACK_SUCCESS = keccak256("ERC3156FlashBorrower.onFlashLoan");
    uint256 public constant BPS_DENOMINATOR = 10_000;

    address public immutable token; // ERC20 token lent by this provider
    address public owner;
    uint256 public feeBps; // e.g., 9 = 0.09%, 30 = 0.30%

    event FlashLoanExecuted(address indexed initiator, address indexed receiver, uint256 amount, uint256 fee);
    event FeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event OwnerUpdated(address indexed oldOwner, address indexed newOwner);
    event TokensDeposited(address indexed from, uint256 amount);
    event TokensWithdrawn(address indexed to, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier nonReentrant() {
        require(_status != _ENTERED, "Reentrancy");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

    constructor(address token_, uint256 feeBps_) {
        require(token_ != address(0), "Token zero");
        require(feeBps_ <= BPS_DENOMINATOR, "Fee too high");
        token = token_;
        owner = msg.sender;
        feeBps = feeBps_;
        _status = _NOT_ENTERED;
    }

    // IERC3156FlashLender

    function maxFlashLoan(address token_) external view override returns (uint256) {
        if (token_ != token) return 0;
        return IERC20(token).balanceOf(address(this));
    }

    function flashFee(address token_, uint256 amount) public view override returns (uint256) {
        require(token_ == token, "Unsupported token");
        // Integer division rounds down; borrower repays amount + fee
        return (amount * feeBps) / BPS_DENOMINATOR;
    }

    function flashLoan(
        IERC3156FlashBorrower receiver,
        address token_,
        uint256 amount,
        bytes calldata data
    ) external override nonReentrant returns (bool) {
        require(token_ == token, "Unsupported token");
        require(address(receiver) != address(0), "Receiver zero");
        require(amount > 0, "Amount zero");

        uint256 balanceBefore = IERC20(token).balanceOf(address(this));
        require(amount <= balanceBefore, "Insufficient liquidity");

        uint256 fee = flashFee(token, amount);

        _safeTransfer(token, address(receiver), amount);

        // Callback to borrower
        bytes32 ret = receiver.onFlashLoan(msg.sender, token, amount, fee, data);
        require(ret == CALLBACK_SUCCESS, "Callback failed");

        // Expect amount + fee returned
        uint256 balanceAfter = IERC20(token).balanceOf(address(this));
        require(balanceAfter >= balanceBefore + fee, "Not repaid");

        emit FlashLoanExecuted(msg.sender, address(receiver), amount, fee);
        return true;
    }

    // Admin

    function setFeeBps(uint256 newFeeBps) external onlyOwner {
        require(newFeeBps <= BPS_DENOMINATOR, "Fee too high");
        uint256 old = feeBps;
        feeBps = newFeeBps;
        emit FeeUpdated(old, newFeeBps);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Owner zero");
        address old = owner;
        owner = newOwner;
        emit OwnerUpdated(old, newOwner);
    }

    function withdraw(address to, uint256 amount) external onlyOwner nonReentrant {
        require(to != address(0), "To zero");
        _safeTransfer(token, to, amount);
        emit TokensWithdrawn(to, amount);
    }

    // Public utility

    function deposit(uint256 amount) external nonReentrant {
        require(amount > 0, "Amount zero");
        _safeTransferFrom(token, msg.sender, address(this), amount);
        emit TokensDeposited(msg.sender, amount);
    }

    function availableLiquidity() external view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }

    // Internal safe ERC20 ops (supports tokens that return no bool or true)

    function _safeTransfer(address token_, address to, uint256 value) internal {
        bytes memory data = abi.encodeWithSelector(IERC20.transfer.selector, to, value);
        _callOptionalReturn(token_, data, "Transfer failed");
    }

    function _safeTransferFrom(address token_, address from, address to, uint256 value) internal {
        bytes memory data = abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, value);
        _callOptionalReturn(token_, data, "TransferFrom failed");
    }

    function _callOptionalReturn(address token_, bytes memory data, string memory err) private {
        (bool success, bytes memory returndata) = token_.call(data);
        require(success, err);
        if (returndata.length > 0) {
            require(abi.decode(returndata, (bool)), err);
        }
    }
}