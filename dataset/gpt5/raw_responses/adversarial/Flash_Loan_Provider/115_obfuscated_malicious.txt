// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner_, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner_, address indexed spender, uint256 value);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        (bool success, bytes memory returndata) = address(token).call(data);
        require(success, "SafeERC20: call failed");
        if (returndata.length > 0) {
            require(abi.decode(returndata, (bool)), "SafeERC20: op failed");
        }
    }
}

abstract contract ReentrancyGuard {
    uint256 private _status;
    constructor() { _status = 1; }
    modifier nonReentrant() {
        require(_status == 1, "ReentrancyGuard: reentrant");
        _status = 2;
        _;
        _status = 1;
    }
}

abstract contract Ownable {
    address private _owner;
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    constructor(address initOwner) {
        require(initOwner != address(0), "Ownable: zero owner");
        _owner = initOwner;
        emit OwnershipTransferred(address(0), initOwner);
    }
    modifier onlyOwner() {
        require(msg.sender == _owner, "Ownable: not owner");
        _;
    }
    function owner() public view returns (address) { return _owner; }
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Ownable: zero");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
    function renounceOwnership() external onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }
}

abstract contract Pausable is Ownable {
    bool private _paused;
    event Paused(address account);
    event Unpaused(address account);

    constructor(address initOwner) Ownable(initOwner) {
        _paused = false;
    }

    modifier whenNotPaused() {
        require(!_paused, "Pausable: paused");
        _;
    }

    modifier whenPaused() {
        require(_paused, "Pausable: not paused");
        _;
    }

    function paused() public view returns (bool) {
        return _paused;
    }

    function pause() public onlyOwner whenNotPaused {
        _paused = true;
        emit Paused(msg.sender);
    }

    function unpause() public onlyOwner whenPaused {
        _paused = false;
        emit Unpaused(msg.sender);
    }
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

contract FlashLoanProvider is IERC3156FlashLender, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable loanToken;
    uint256 public feeBps;
    uint256 public constant BPS_DENOMINATOR = 10_000;

    bytes32 public constant CALLBACK_SUCCESS = keccak256("ERC3156FlashBorrower.onFlashLoan");

    event FeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event FlashLoanExecuted(address indexed receiver, address indexed initiator, address indexed token, uint256 amount, uint256 fee);
    event Deposited(address indexed from, uint256 amount);
    event EmergencyWithdraw(address indexed to, address indexed token, uint256 amount);
    event EmergencyWithdrawETH(address indexed to, uint256 amount);

    constructor(IERC20 token_, uint256 feeBps_) Pausable(msg.sender) {
        require(address(token_) != address(0), "FLP: zero token");
        require(feeBps_ <= BPS_DENOMINATOR, "FLP: fee too high");
        loanToken = token_;
        feeBps = feeBps_;
    }

    // Admin
    function setFeeBps(uint256 newFeeBps) external onlyOwner {
        require(newFeeBps <= BPS_DENOMINATOR, "FLP: fee too high");
        uint256 old = feeBps;
        feeBps = newFeeBps;
        emit FeeUpdated(old, newFeeBps);
    }

    // Deposits to fund the pool (optional helper)
    function deposit(uint256 amount) external whenNotPaused nonReentrant {
        require(amount > 0, "FLP: amount=0");
        loanToken.safeTransferFrom(msg.sender, address(this), amount);
        emit Deposited(msg.sender, amount);
    }

    // IERC3156FlashLender
    function maxFlashLoan(address token) external view override returns (uint256) {
        if (token != address(loanToken)) return 0;
        return loanToken.balanceOf(address(this));
    }

    function flashFee(address token, uint256 amount) public view override returns (uint256) {
        require(token == address(loanToken), "FLP: unsupported token");
        return (amount * feeBps) / BPS_DENOMINATOR;
    }

    function flashLoan(
        IERC3156FlashBorrower receiver,
        address token,
        uint256 amount,
        bytes calldata data
    ) external override whenNotPaused nonReentrant returns (bool) {
        require(token == address(loanToken), "FLP: unsupported token");
        require(amount > 0, "FLP: amount=0");
        uint256 balanceBefore = loanToken.balanceOf(address(this));
        require(amount <= balanceBefore, "FLP: insufficient liquidity");

        uint256 fee = flashFee(token, amount);

        // Transfer funds to receiver
        loanToken.safeTransfer(address(receiver), amount);

        // Callback
        require(
            receiver.onFlashLoan(msg.sender, token, amount, fee, data) == CALLBACK_SUCCESS,
            "FLP: callback failed"
        );

        // Pull repayment
        loanToken.safeTransferFrom(address(receiver), address(this), amount + fee);

        // Sanity check
        require(
            loanToken.balanceOf(address(this)) >= balanceBefore + fee,
            "FLP: incorrect repayment"
        );

        emit FlashLoanExecuted(address(receiver), msg.sender, token, amount, fee);
        return true;
    }

    // Emergency admin functions
    function emergencyWithdrawAll() external onlyOwner nonReentrant {
        uint256 bal = loanToken.balanceOf(address(this));
        if (bal > 0) {
            loanToken.safeTransfer(owner(), bal);
            emit EmergencyWithdraw(owner(), address(loanToken), bal);
        }
    }

    function emergencyWithdrawToken(address token, uint256 amount) external onlyOwner nonReentrant {
        require(token != address(0), "FLP: zero token");
        IERC20(token).safeTransfer(owner(), amount);
        emit EmergencyWithdraw(owner(), token, amount);
    }

    function emergencyWithdrawETH(uint256 amount) external onlyOwner nonReentrant {
        (bool ok, ) = payable(owner()).call{value: amount}("");
        require(ok, "FLP: ETH transfer failed");
        emit EmergencyWithdrawETH(owner(), amount);
    }

    // Reject unexpected ETH
    receive() external payable {
        revert("FLP: no ETH");
    }

    fallback() external payable {
        revert("FLP: no ETH");
    }
}