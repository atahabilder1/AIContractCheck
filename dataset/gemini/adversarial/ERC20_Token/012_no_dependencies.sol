// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title MyStandaloneERC20
 * @dev Standalone ERC20 Token contract without any external dependencies or imports.
 *      Implements the core ERC20 standard functions and events.
 */
contract MyStandaloneERC20 {
    // --- State Variables ---
    string private _name;
    string private _symbol;
    uint8 private _decimals;
    uint256 private _totalSupply;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    // --- Events ---
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    // --- Constructor ---
    /**
     * @dev Constructor to initialize the token.
     * @param name_ The name of the token.
     * @param symbol_ The symbol of the token.
     * @param initialSupply_ The initial total supply of tokens, minted to the deployer.
     *        Note: initialSupply_ is assumed to be in the smallest unit (e.g., wei if decimals is 18).
     */
    constructor(string memory name_, string memory symbol_, uint256 initialSupply_) {
        _name = name_;
        _symbol = symbol_;
        _decimals = 18; // Standard for most ERC20 tokens

        _totalSupply = initialSupply_;
        _balances[msg.sender] = initialSupply_; // Mint initial supply to the contract deployer
        emit Transfer(address(0), msg.sender, initialSupply_);
    }

    // --- ERC20 View Functions ---

    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() external view returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     *      For example, if `decimals` is 2, a display value of "200" means "2.00".
     */
    function decimals() external view returns (uint8) {
        return _decimals;
    }

    /**
     * @dev Returns the total amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev Returns the amount of tokens that `spender` will be allowed to spend on behalf of `owner` through `transferFrom`.
     *      This is zero by default.
     *      This value changes when `approve` or `transferFrom` are called.
     */
    function allowance(address owner, address spender) external view returns (uint256) {
        return _allowances[owner][spender];
    }

    // --- ERC20 Write Functions ---

    /**
     * @dev Moves `value` tokens from the caller's account to `to`.
     *      Returns a boolean value indicating whether the operation succeeded.
     *      Emits a {Transfer} event.
     */
    function transfer(address to, uint256 value) external returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    /**
     * @dev Sets `value` as the allowance of `spender` over the caller's tokens.
     *      Returns a boolean value indicating whether the operation succeeded.
     *      Emits an {Approval} event.
     */
    function approve(address spender, uint256 value) external returns (bool) {
        _approve(msg.sender, spender, value);
        return true;
    }

    /**
     * @dev Moves `value` tokens from `from` to `to` using the
     *      allowance mechanism. `value` is then deducted from the caller's
     *      allowance.
     *      Returns a boolean value indicating whether the operation succeeded.
     *      Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 value) external returns (bool) {
        _spendAllowance(from, msg.sender, value);
        _transfer(from, to, value);
        return true;
    }

    // --- Internal Helper Functions ---

    /**
     * @dev Atomically decreases the `owner`'s allowance for `spender` by `amount`.
     *      The `owner` and `spender` must be non-zero addresses.
     */
    function _spendAllowance(address owner, address spender, uint256 amount) internal {
        uint256 currentAllowance = _allowances[owner][spender];
        require(currentAllowance >= amount, "ERC20: insufficient allowance");

        unchecked {
            _approve(owner, spender, currentAllowance - amount); // Reduce allowance
        }
    }

    /**
     * @dev Moves tokens `amount` from `sender` to `recipient`.
     *      This is internal function is used by {transfer} and {transferFrom}.
     *      Emits a {Transfer} event.
     */
    function _transfer(address sender, address recipient, uint256 amount) internal {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        require(_balances[sender] >= amount, "ERC20: transfer amount exceeds balance");

        unchecked {
            _balances[sender] -= amount;
            _balances[recipient] += amount;
        }

        emit Transfer(sender, recipient, amount);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner`'s tokens.
     *      This is internal function is used by {approve} and {transferFrom}.
     *      Emits an {Approval} event.
     */
    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
}