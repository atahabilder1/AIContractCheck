2// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract ProductionERC20Token {
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;
    uint256 public totalSupply;
    uint256 public maxSupply;
    address public owner;
    bool public paused;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => bool) public blacklisted;
    mapping(address => bool) public minters;

    // Snapshot functionality
    uint256 private _currentSnapshotId;
    mapping(address => mapping(uint256 => uint256)) private _snapshotBalances;
    mapping(address => mapping(uint256 => bool)) private _snapshotTaken;
    mapping(uint256 => uint256) private _snapshotTotalSupply;

    // Governance
    mapping(address => address) public delegates;
    mapping(address => uint256) public votingPower;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event Paused(address account);
    event Unpaused(address account);
    event Blacklisted(address indexed account);
    event Unblacklisted(address indexed account);
    event MinterAdded(address indexed account);
    event MinterRemoved(address indexed account);
    event Snapshot(uint256 id);
    event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier onlyMinter() {
        require(minters[msg.sender] || msg.sender == owner, "Not minter");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "Contract paused");
        _;
    }

    modifier notBlacklisted(address account) {
        require(!blacklisted[account], "Account blacklisted");
        _;
    }

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _initialSupply,
        uint256 _maxSupply
    ) {
        require(_initialSupply <= _maxSupply, "Initial exceeds max");
        name = _name;
        symbol = _symbol;
        owner = msg.sender;
        maxSupply = _maxSupply * 10 ** decimals;
        _mint(msg.sender, _initialSupply * 10 ** decimals);
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function allowance(address tokenOwner, address spender) public view returns (uint256) {
        return _allowances[tokenOwner][spender];
    }

    function transfer(address to, uint256 value) public whenNotPaused notBlacklisted(msg.sender) notBlacklisted(to) returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function approve(address spender, uint256 value) public whenNotPaused notBlacklisted(msg.sender) returns (bool) {
        _approve(msg.sender, spender, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) public whenNotPaused notBlacklisted(from) notBlacklisted(to) returns (bool) {
        uint256 currentAllowance = _allowances[from][msg.sender];
        require(currentAllowance >= value, "Allowance exceeded");
        unchecked {
            _approve(from, msg.sender, currentAllowance - value);
        }
        _transfer(from, to, value);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public whenNotPaused returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender] + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public whenNotPaused returns (bool) {
        uint256 currentAllowance = _allowances[msg.sender][spender];
        require(currentAllowance >= subtractedValue, "Decreased below zero");
        unchecked {
            _approve(msg.sender, spender, currentAllowance - subtractedValue);
        }
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(from != address(0), "Transfer from zero");
        require(to != address(0), "Transfer to zero");
        require(_balances[from] >= amount, "Insufficient balance");

        _updateSnapshot(from);
        _updateSnapshot(to);

        unchecked {
            _balances[from] -= amount;
            _balances[to] += amount;
        }

        _moveDelegates(delegates[from], delegates[to], amount);
        emit Transfer(from, to, amount);
    }

    function _approve(address tokenOwner, address spender, uint256 amount) internal {
        require(tokenOwner != address(0), "Approve from zero");
        require(spender != address(0), "Approve to zero");
        _allowances[tokenOwner][spender] = amount;
        emit Approval(tokenOwner, spender, amount);
    }

    function _mint(address to, uint256 amount) internal {
        require(to != address(0), "Mint to zero");
        require(totalSupply + amount <= maxSupply, "Exceeds max supply");

        _updateSnapshot(to);
        totalSupply += amount;
        _balances[to] += amount;
        _moveDelegates(address(0), delegates[to], amount);
        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        require(from != address(0), "Burn from zero");
        require(_balances[from] >= amount, "Burn exceeds balance");

        _updateSnapshot(from);
        unchecked {
            _balances[from] -= amount;
            totalSupply -= amount;
        }
        _moveDelegates(delegates[from], address(0), amount);
        emit Transfer(from, address(0), amount);
    }

    function mint(address to, uint256 amount) external onlyMinter {
        _mint(to, amount);
    }

    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    function burnFrom(address from, uint256 amount) external {
        uint256 currentAllowance = _allowances[from][msg.sender];
        require(currentAllowance >= amount, "Burn exceeds allowance");
        unchecked {
            _approve(from, msg.sender, currentAllowance - amount);
        }
        _burn(from, amount);
    }

    // Snapshot functions
    function snapshot() external onlyOwner returns (uint256) {
        _currentSnapshotId++;
        _snapshotTotalSupply[_currentSnapshotId] = totalSupply;
        emit Snapshot(_currentSnapshotId);
        return _currentSnapshotId;
    }

    function _updateSnapshot(address account) private {
        if (!_snapshotTaken[account][_currentSnapshotId] && _currentSnapshotId > 0) {
            _snapshotBalances[account][_currentSnapshotId] = _balances[account];
            _snapshotTaken[account][_currentSnapshotId] = true;
        }
    }

    function balanceOfAt(address account, uint256 snapshotId) public view returns (uint256) {
        require(snapshotId > 0 && snapshotId <= _currentSnapshotId, "Invalid snapshot");
        if (_snapshotTaken[account][snapshotId]) {
            return _snapshotBalances[account][snapshotId];
        }
        return _balances[account];
    }

    // Delegation functions
    function delegate(address delegatee) external {
        address currentDelegate = delegates[msg.sender];
        delegates[msg.sender] = delegatee;
        emit DelegateChanged(msg.sender, currentDelegate, delegatee);
        _moveDelegates(currentDelegate, delegatee, _balances[msg.sender]);
    }

    function _moveDelegates(address from, address to, uint256 amount) internal {
        if (from != address(0)) {
            votingPower[from] -= amount;
        }
        if (to != address(0)) {
            votingPower[to] += amount;
        }
    }

    // Admin functions
    function pause() external onlyOwner {
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOwner {
        paused = false;
        emit Unpaused(msg.sender);
    }

    function blacklist(address account) external onlyOwner {
        blacklisted[account] = true;
        emit Blacklisted(account);
    }

    function unblacklist(address account) external onlyOwner {
        blacklisted[account] = false;
        emit Unblacklisted(account);
    }

    function addMinter(address account) external onlyOwner {
        minters[account] = true;
        emit MinterAdded(account);
    }

    function removeMinter(address account) external onlyOwner {
        minters[account] = false;
        emit MinterRemoved(account);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid new owner");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function renounceOwnership() external onlyOwner {
        emit OwnershipTransferred(owner, address(0));
        owner = address(0);
    }
}
