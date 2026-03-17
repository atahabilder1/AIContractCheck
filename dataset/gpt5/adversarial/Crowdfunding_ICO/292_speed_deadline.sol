// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract HackathonICO {
    // --- ERC20 Minimal Implementation ---
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;

    uint256 public totalSupply;
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function allowance(address owner_, address spender) public view returns (uint256) {
        return _allowances[owner_][spender];
    }

    function transfer(address to, uint256 value) public returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function approve(address spender, uint256 value) public returns (bool) {
        _approve(msg.sender, spender, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) public returns (bool) {
        uint256 allowed = _allowances[from][msg.sender];
        require(allowed >= value, "ERC20: insufficient allowance");
        _transfer(from, to, value);
        _approve(from, msg.sender, allowed - value);
        return true;
    }

    function _transfer(address from, address to, uint256 value) internal {
        require(to != address(0), "ERC20: to zero");
        uint256 bal = _balances[from];
        require(bal >= value, "ERC20: balance too low");
        unchecked {
            _balances[from] = bal - value;
        }
        _balances[to] += value;
        emit Transfer(from, to, value);
    }

    function _approve(address owner_, address spender, uint256 value) internal {
        require(spender != address(0), "ERC20: spender zero");
        _allowances[owner_][spender] = value;
        emit Approval(owner_, spender, value);
    }

    function _mint(address to, uint256 value) internal {
        require(to != address(0), "ERC20: mint to zero");
        totalSupply += value;
        _balances[to] += value;
        emit Transfer(address(0), to, value);
    }

    // --- Reentrancy Guard ---
    uint256 private _unlocked = 1;
    modifier nonReentrant() {
        require(_unlocked == 1, "ReentrancyGuard");
        _unlocked = 2;
        _;
        _unlocked = 1;
    }

    // --- ICO State ---
    address public owner;
    uint64 public startTime;
    uint64 public endTime;

    // tokensPerEther: number of tokens minted per 1 ether contributed (with 18 decimals)
    uint256 public tokensPerEther;

    uint256 public softCap; // in wei
    uint256 public hardCap; // in wei

    uint256 public totalRaised; // in wei
    bool public finalized;
    bool public successful;

    mapping(address => uint256) public contributions; // in wei
    mapping(address => bool) public tokensClaimed;

    // --- Events ---
    event ContributionReceived(address indexed contributor, uint256 amount);
    event Finalized(bool successful, uint256 totalRaised);
    event TokensClaimed(address indexed claimer, uint256 tokenAmount);
    event RefundClaimed(address indexed claimer, uint256 amount);
    event FundsWithdrawn(address indexed to, uint256 amount);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // --- Constructor ---
    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _tokensPerEther,
        uint64 _startTime,
        uint64 _endTime,
        uint256 _softCap,
        uint256 _hardCap
    ) {
        require(_startTime < _endTime, "Invalid time window");
        require(_softCap <= _hardCap, "Soft > hard cap");
        require(_hardCap > 0, "Hard cap = 0");
        require(_tokensPerEther > 0, "Rate = 0");

        owner = msg.sender;
        name = _name;
        symbol = _symbol;

        tokensPerEther = _tokensPerEther;
        startTime = _startTime;
        endTime = _endTime;
        softCap = _softCap;
        hardCap = _hardCap;
    }

    // --- Modifiers ---
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    // --- Ownership ---
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Zero owner");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    // --- Contribute ---
    function buy() public payable {
        require(block.timestamp >= startTime, "Sale not started");
        require(block.timestamp <= endTime, "Sale ended");
        require(msg.value > 0, "No ETH sent");
        require(totalRaised + msg.value <= hardCap, "Exceeds hard cap");

        contributions[msg.sender] += msg.value;
        totalRaised += msg.value;

        emit ContributionReceived(msg.sender, msg.value);
    }

    receive() external payable {
        buy();
    }

    // --- Finalize ---
    function finalize() external onlyOwner {
        require(!finalized, "Already finalized");
        require(block.timestamp > endTime || totalRaised == hardCap, "Sale not over");

        successful = totalRaised >= softCap;
        finalized = true;

        emit Finalized(successful, totalRaised);
    }

    // --- Claim Tokens (post-success) ---
    function claimTokens() external {
        require(finalized, "Not finalized");
        require(successful, "Sale failed");
        require(!tokensClaimed[msg.sender], "Already claimed");

        uint256 contributed = contributions[msg.sender];
        require(contributed > 0, "No contribution");

        tokensClaimed[msg.sender] = true;

        uint256 tokenAmount = (contributed * tokensPerEther) / 1 ether;
        require(tokenAmount > 0, "Zero tokens");

        _mint(msg.sender, tokenAmount);

        emit TokensClaimed(msg.sender, tokenAmount);
    }

    // --- Refund (post-failure) ---
    function claimRefund() external nonReentrant {
        require(finalized, "Not finalized");
        require(!successful, "Sale succeeded");

        uint256 amount = contributions[msg.sender];
        require(amount > 0, "Nothing to refund");

        contributions[msg.sender] = 0;

        (bool ok, ) = msg.sender.call{value: amount}("");
        require(ok, "Refund failed");

        emit RefundClaimed(msg.sender, amount);
    }

    // --- Withdraw Funds (post-success) ---
    function withdrawFunds(address payable to) external onlyOwner nonReentrant {
        require(finalized && successful, "Not allowed");
        require(to != address(0), "Zero to");
        uint256 bal = address(this).balance;
        require(bal > 0, "No funds");

        (bool ok, ) = to.call{value: bal}("");
        require(ok, "Withdraw failed");

        emit FundsWithdrawn(to, bal);
    }

    // --- View Helpers ---
    function claimableTokens(address account) external view returns (uint256) {
        if (!finalized || !successful || tokensClaimed[account]) {
            return 0;
        }
        uint256 contributed = contributions[account];
        if (contributed == 0) return 0;
        return (contributed * tokensPerEther) / 1 ether;
    }

    function isLive() external view returns (bool) {
        return block.timestamp >= startTime && block.timestamp <= endTime && !finalized && totalRaised < hardCap;
    }
}