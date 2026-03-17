// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
    function allowance(address owner_, address spender) external view returns (uint256);
    function approve(address spender, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        bytes memory data = abi.encodeWithSelector(token.transfer.selector, to, value);
        bytes memory returndata = _callOptionalReturn(address(token), data);
        if (returndata.length > 0) {
            require(abi.decode(returndata, (bool)), "SafeERC20: transfer failed");
        }
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        bytes memory data = abi.encodeWithSelector(token.transferFrom.selector, from, to, value);
        bytes memory returndata = _callOptionalReturn(address(token), data);
        if (returndata.length > 0) {
            require(abi.decode(returndata, (bool)), "SafeERC20: transferFrom failed");
        }
    }

    function _callOptionalReturn(address target, bytes memory data) private returns (bytes memory) {
        (bool success, bytes memory returndata) = target.call(data);
        require(success, "SafeERC20: low-level call failed");
        return returndata;
    }
}

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
}

abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        address sender = _msgSender();
        _transferOwnership(sender);
    }

    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is zero");
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal {
        address old = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(old, newOwner);
    }
}

abstract contract Pausable is Context {
    event Paused(address account);
    event Unpaused(address account);

    bool private _paused;

    constructor() {
        _paused = false;
    }

    function paused() public view virtual returns (bool) {
        return _paused;
    }

    modifier whenNotPaused() {
        require(!paused(), "Pausable: paused");
        _;
    }

    modifier whenPaused() {
        require(paused(), "Pausable: not paused");
        _;
    }

    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }

    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
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

contract CrowdfundingICO is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // Token being sold
    IERC20 public immutable token;

    // Rate: number of token units per 1 ether contributed (token units include token decimals)
    uint256 public rate;

    // Contribution tracking
    uint256 public weiRaised;
    uint256 public immutable cap; // Total cap in wei
    uint256 public minContribution; // per tx or per address min contribution in wei
    uint256 public maxContribution; // per address cap in wei

    uint64 public startTime; // unix timestamp
    uint64 public endTime;   // unix timestamp

    mapping(address => uint256) public contributions;

    // Events
    event TokensPurchased(address indexed purchaser, address indexed beneficiary, uint256 value, uint256 amount);
    event FundsWithdrawn(address indexed to, uint256 amount);
    event EmergencyWithdrawETH(address indexed to, uint256 amount);
    event EmergencyWithdrawERC20(address indexed token, address indexed to, uint256 amount);
    event ParametersUpdated(uint256 rate, uint256 minContribution, uint256 maxContribution, uint64 startTime, uint64 endTime);

    constructor(
        IERC20 token_,
        uint256 rate_,                 // tokens per ETH (in token's smallest units)
        uint256 cap_,                  // total cap in wei
        uint256 minContribution_,      // minimum contribution per tx/address in wei
        uint256 maxContribution_,      // maximum cumulative contribution per address in wei
        uint64 startTime_,             // sale start timestamp
        uint64 endTime_                // sale end timestamp
    ) {
        require(address(token_) != address(0), "Token is zero");
        require(rate_ > 0, "Rate is zero");
        require(cap_ > 0, "Cap is zero");
        require(endTime_ > startTime_, "Invalid time window");

        token = token_;
        rate = rate_;
        cap = cap_;
        minContribution = minContribution_;
        maxContribution = maxContribution_;
        startTime = startTime_;
        endTime = endTime_;
    }

    // Fallback to buy tokens by sending ETH directly
    receive() external payable {
        _buyTokens(_msgSender());
    }

    function buyTokens(address beneficiary) external payable nonReentrant whenNotPaused {
        require(beneficiary != address(0), "Beneficiary is zero");
        _buyTokens(beneficiary);
    }

    function _buyTokens(address beneficiary) internal {
        require(isOpen(), "Sale not open");
        uint256 weiAmount = msg.value;
        require(weiAmount > 0, "Zero value");
        require(weiRaised + weiAmount <= cap, "Cap exceeded");
        require(weiAmount >= minContribution, "Below min contribution");

        uint256 newContribution = contributions[beneficiary] + weiAmount;
        require(maxContribution == 0 || newContribution <= maxContribution, "Above max contribution");

        // Calculate token amount to be created
        uint256 tokens = weiAmount * rate / 1 ether;
        require(tokens > 0, "Zero tokens");
        require(token.balanceOf(address(this)) >= tokens, "Insufficient token liquidity");

        // Effects
        weiRaised += weiAmount;
        contributions[beneficiary] = newContribution;

        // Interactions - deliver tokens
        token.safeTransfer(beneficiary, tokens);

        emit TokensPurchased(_msgSender(), beneficiary, weiAmount, tokens);
    }

    // View helpers
    function isOpen() public view returns (bool) {
        return block.timestamp >= startTime && block.timestamp <= endTime && !paused();
    }

    function tokensForWei(uint256 weiAmount) external view returns (uint256) {
        return weiAmount * rate / 1 ether;
    }

    // Admin controls
    function emergencyPause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function setParameters(
        uint256 newRate,
        uint256 newMinContribution,
        uint256 newMaxContribution,
        uint64 newStartTime,
        uint64 newEndTime
    ) external onlyOwner {
        require(newRate > 0, "Rate is zero");
        require(newEndTime > newStartTime, "Invalid time window");
        // Allow changing window only if sale not started or paused (owner responsibility)
        rate = newRate;
        minContribution = newMinContribution;
        maxContribution = newMaxContribution;
        startTime = newStartTime;
        endTime = newEndTime;
        emit ParametersUpdated(newRate, newMinContribution, newMaxContribution, newStartTime, newEndTime);
    }

    // Withdraw functions
    function withdraw(uint256 amount, address payable to) external onlyOwner nonReentrant {
        require(to != address(0), "Recipient is zero");
        require(amount > 0, "Amount is zero");
        require(address(this).balance >= amount, "Insufficient ETH");
        (bool ok, ) = to.call{value: amount}("");
        require(ok, "ETH transfer failed");
        emit FundsWithdrawn(to, amount);
    }

    // Emergency: withdraw all ETH
    function emergencyWithdrawAllETH(address payable to) external onlyOwner nonReentrant {
        require(to != address(0), "Recipient is zero");
        uint256 bal = address(this).balance;
        (bool ok, ) = to.call{value: bal}("");
        require(ok, "ETH transfer failed");
        emit EmergencyWithdrawETH(to, bal);
    }

    // Emergency: rescue arbitrary ERC20 (including unsold sale tokens)
    function emergencyWithdrawERC20(IERC20 token_, address to, uint256 amount) external onlyOwner nonReentrant {
        require(to != address(0), "Recipient is zero");
        token_.safeTransfer(to, amount);
        emit EmergencyWithdrawERC20(address(token_), to, amount);
    }
}