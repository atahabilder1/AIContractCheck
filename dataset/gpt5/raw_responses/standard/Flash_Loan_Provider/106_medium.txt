// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
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

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        bytes memory data = abi.encodeWithSelector(token.transfer.selector, to, value);
        (bool success, bytes memory ret) = address(token).call(data);
        require(success && (ret.length == 0 || abi.decode(ret, (bool))), "SafeERC20: transfer failed");
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        bytes memory data = abi.encodeWithSelector(token.transferFrom.selector, from, to, value);
        (bool success, bytes memory ret) = address(token).call(data);
        require(success && (ret.length == 0 || abi.decode(ret, (bool))), "SafeERC20: transferFrom failed");
    }
}

abstract contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status = _NOT_ENTERED;

    modifier nonReentrant() {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
}

contract Ownable {
    address public owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Ownable: not owner");
        _;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Ownable: zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
}

contract MultiTokenFlashLender is IERC3156FlashLender, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // token => enabled
    mapping(address => bool) public supportedToken;

    // token => fee in basis points (10000 = 100%). If 0, defaultFeeBps applies.
    mapping(address => uint256) public feeBps;

    // Default fee in basis points for tokens without a specific fee override.
    uint256 public defaultFeeBps;

    uint256 public constant BPS_DENOMINATOR = 10_000;
    bytes32 public constant CALLBACK_SUCCESS = keccak256("ERC3156FlashBorrower.onFlashLoan");

    event SupportedTokenUpdated(address indexed token, bool enabled);
    event FeeUpdated(address indexed token, uint256 feeBps);
    event DefaultFeeUpdated(uint256 feeBps);
    event FlashLoanExecuted(address indexed receiver, address indexed token, uint256 amount, uint256 fee);
    event Rescue(address indexed token, address indexed to, uint256 amount);

    constructor(uint256 _defaultFeeBps) {
        require(_defaultFeeBps <= BPS_DENOMINATOR, "Fee too high");
        defaultFeeBps = _defaultFeeBps;
        emit DefaultFeeUpdated(_defaultFeeBps);
    }

    function setSupportedToken(address token, bool enabled) external onlyOwner {
        require(token != address(0), "Invalid token");
        supportedToken[token] = enabled;
        emit SupportedTokenUpdated(token, enabled);
    }

    function setFeeBps(address token, uint256 _feeBps) external onlyOwner {
        require(_feeBps <= BPS_DENOMINATOR, "Fee too high");
        feeBps[token] = _feeBps;
        emit FeeUpdated(token, _feeBps);
    }

    function setDefaultFeeBps(uint256 _defaultFeeBps) external onlyOwner {
        require(_defaultFeeBps <= BPS_DENOMINATOR, "Fee too high");
        defaultFeeBps = _defaultFeeBps;
        emit DefaultFeeUpdated(_defaultFeeBps);
    }

    function rescueTokens(address token, address to, uint256 amount) external onlyOwner {
        require(to != address(0), "Invalid to");
        IERC20(token).safeTransfer(to, amount);
        emit Rescue(token, to, amount);
    }

    function maxFlashLoan(address token) external view override returns (uint256) {
        if (!supportedToken[token]) return 0;
        return IERC20(token).balanceOf(address(this));
    }

    function flashFee(address token, uint256 amount) public view override returns (uint256) {
        require(supportedToken[token], "Unsupported token");
        uint256 bps = feeBps[token];
        if (bps == 0) bps = defaultFeeBps;
        return (amount * bps) / BPS_DENOMINATOR;
    }

    function flashLoan(
        IERC3156FlashBorrower receiver,
        address token,
        uint256 amount,
        bytes calldata data
    ) external override nonReentrant returns (bool) {
        require(supportedToken[token], "Unsupported token");

        IERC20 t = IERC20(token);
        uint256 balanceBefore = t.balanceOf(address(this));
        require(amount > 0 && amount <= balanceBefore, "Invalid amount");

        uint256 fee = flashFee(token, amount);

        // Send funds to the receiver
        t.safeTransfer(address(receiver), amount);

        // Execute receiver callback
        require(
            receiver.onFlashLoan(msg.sender, token, amount, fee, data) == CALLBACK_SUCCESS,
            "Callback failed"
        );

        // Pull back principal + fee from receiver
        uint256 repayment = amount + fee;
        require(t.allowance(address(receiver), address(this)) >= repayment, "Insufficient allowance");
        t.safeTransferFrom(address(receiver), address(this), repayment);

        // Validate repayment
        uint256 balanceAfter = t.balanceOf(address(this));
        require(balanceAfter >= balanceBefore + fee, "Invalid repayment");

        emit FlashLoanExecuted(address(receiver), token, amount, fee);
        return true;
    }
}