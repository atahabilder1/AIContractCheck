// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
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

abstract contract Ownable {
    address public owner;
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Ownable: caller is not the owner");
        _;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Ownable: zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
}

abstract contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    modifier nonReentrant() {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
}

contract FlashLoanProvider is IERC3156FlashLender, Ownable, ReentrancyGuard {
    bytes32 public constant CALLBACK_SUCCESS = keccak256("ERC3156FlashBorrower.onFlashLoan");
    IERC20 public immutable token;

    // fee in basis points (bps), where 10000 = 100%
    uint256 public feeBps;

    event FlashLoan(address indexed receiver, address indexed initiator, address indexed token, uint256 amount, uint256 fee);
    event FeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event Deposited(address indexed from, uint256 amount);
    event Withdrawn(address indexed to, uint256 amount);

    constructor(address token_, uint256 feeBps_) {
        require(token_ != address(0), "token zero");
        require(feeBps_ <= 10000, "fee too high");
        token = IERC20(token_);
        feeBps = feeBps_;
    }

    function setFeeBps(uint256 newFeeBps) external onlyOwner {
        require(newFeeBps <= 10000, "fee too high");
        emit FeeUpdated(feeBps, newFeeBps);
        feeBps = newFeeBps;
    }

    function deposit(uint256 amount) external nonReentrant {
        require(amount > 0, "amount=0");
        require(token.transferFrom(msg.sender, address(this), amount), "transferFrom failed");
        emit Deposited(msg.sender, amount);
    }

    function withdraw(uint256 amount, address to) external onlyOwner nonReentrant {
        require(to != address(0), "to zero");
        require(amount > 0, "amount=0");
        require(token.balanceOf(address(this)) >= amount, "insufficient balance");
        require(token.transfer(to, amount), "transfer failed");
        emit Withdrawn(to, amount);
    }

    function liquidity() external view returns (uint256) {
        return token.balanceOf(address(this));
    }

    function maxFlashLoan(address token_) external view override returns (uint256) {
        if (token_ != address(token)) return 0;
        return token.balanceOf(address(this));
    }

    function flashFee(address token_, uint256 amount) public view override returns (uint256) {
        require(token_ == address(token), "unsupported token");
        return (amount * feeBps) / 10000;
    }

    function flashLoan(IERC3156FlashBorrower receiver, address token_, uint256 amount, bytes calldata data)
        external
        override
        nonReentrant
        returns (bool)
    {
        require(token_ == address(token), "unsupported token");
        require(amount > 0, "amount=0");
        uint256 available = token.balanceOf(address(this));
        require(available >= amount, "insufficient liquidity");

        uint256 fee = flashFee(token_, amount);

        // Transfer the tokens to the receiver
        require(token.transfer(address(receiver), amount), "transfer to receiver failed");

        // Callback
        require(
            receiver.onFlashLoan(msg.sender, token_, amount, fee, data) == CALLBACK_SUCCESS,
            "callback failed"
        );

        // Pull back amount + fee via allowance
        uint256 repayment = amount + fee;
        require(
            token.allowance(address(receiver), address(this)) >= repayment,
            "insufficient allowance for repayment"
        );
        require(token.transferFrom(address(receiver), address(this), repayment), "repayment failed");

        emit FlashLoan(address(receiver), msg.sender, token_, amount, fee);
        return true;
    }
}