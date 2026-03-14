// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract WrappedToken is ERC20, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable underlyingToken;
    uint256 public unwrapFee; // fee in basis points (e.g., 50 for 0.5%)
    uint256 public totalFeesCollected;
    mapping(address => uint256) public lastUnwrapTime;

    event Wrapped(address indexed user, uint256 amount);
    event Unwrapped(address indexed user, uint256 amount);
    event FeeDistributed(uint256 amount);

    constructor(IERC20 _underlyingToken, uint256 _unwrapFee) ERC20("Wrapped Token", "WTKN") {
        underlyingToken = _underlyingToken;
        unwrapFee = _unwrapFee;
    }

    function wrap(uint256 amount) external nonReentrant {
        require(amount > 0, "Amount must be greater than zero");
        underlyingToken.safeTransferFrom(msg.sender, address(this), amount);
        _mint(msg.sender, amount);
        emit Wrapped(msg.sender, amount);
    }

    function unwrap(uint256 amount) external nonReentrant {
        require(amount > 0, "Amount must be greater than zero");
        _burn(msg.sender, amount);

        uint256 fee = (amount * unwrapFee) / 10000;
        uint256 amountAfterFee = amount - fee;

        totalFeesCollected += fee;
        lastUnwrapTime[msg.sender] = block.timestamp;

        underlyingToken.safeTransfer(msg.sender, amountAfterFee);
        emit Unwrapped(msg.sender, amountAfterFee);
    }

    function distributeFees() external nonReentrant {
        uint256 totalSupply = totalSupply();
        require(totalSupply > 0, "No tokens in circulation");

        uint256 feesToDistribute = totalFeesCollected;
        totalFeesCollected = 0;

        for (uint256 i = 0; i < _holders.length; i++) {
            address holder = _holders[i];
            if (balanceOf(holder) > 0 && block.timestamp - lastUnwrapTime[holder] > 30 days) {
                uint256 holderShare = (balanceOf(holder) * feesToDistribute) / totalSupply;
                if (holderShare > 0) {
                    underlyingToken.safeTransfer(holder, holderShare);
                }
            }
        }
        emit FeeDistributed(feesToDistribute);
    }

    address[] private _holders;

    function _mint(address account, uint256 amount) internal override {
        if (balanceOf(account) == 0) {
            _holders.push(account);
        }
        super._mint(account, amount);
    }

    function _burn(address account, uint256 amount) internal override {
        super._burn(account, amount);
        if (balanceOf(account) == 0) {
            _removeHolder(account);
        }
    }

    function _removeHolder(address account) private {
        uint256 length = _holders.length;
        for (uint256 i = 0; i < length; i++) {
            if (_holders[i] == account) {
                _holders[i] = _holders[length - 1];
                _holders.pop();
                break;
            }
        }
    }
}