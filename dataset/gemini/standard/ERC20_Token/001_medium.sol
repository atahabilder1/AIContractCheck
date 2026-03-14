// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/**
 * @title MyAdvancedToken
 * @dev An ERC20 token with burn, pause, blacklist, and owner-mintable functionalities.
 */
contract MyAdvancedToken is ERC20, Ownable, ERC20Burnable, Pausable {

    // --- Blacklist functionality ---
    mapping(address => bool) private _isBlacklisted;
    event Blacklisted(address indexed account);
    event Unblacklisted(address indexed account);

    /**
     * @dev Constructor that sets the initial supply of the token and assigns it to the deployer.
     * @param name The name of the token.
     * @param symbol The symbol of the token.
     * @param initialSupply The initial amount of tokens to mint.
     */
    constructor(string memory name, string memory symbol, uint256 initialSupply)
        ERC20(name, symbol)
        Ownable(msg.sender) // Sets the deployer as the initial owner
    {
        _mint(msg.sender, initialSupply);
    }

    // --- Pausable functionality ---

    /**
     * @dev Pauses all token transfers and approvals.
     * Only the owner can call this function.
     */
    function pause() public onlyOwner {
        _pause();
    }

    /**
     * @dev Unpauses all token transfers and approvals.
     * Only the owner can call this function.
     */
    function unpause() public onlyOwner {
        _unpause();
    }

    // --- Minting functionality ---

    /**
     * @dev Mints `amount` tokens to `to`.
     * Only the owner can call this function.
     * @param to The address that will receive the minted tokens.
     * @param amount The amount of tokens to mint.
     */
    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    // --- Blacklist functionality ---

    /**
     * @dev Returns true if `account` is blacklisted.
     * @param account The address to check.
     */
    function isBlacklisted(address account) public view returns (bool) {
        return _isBlacklisted[account];
    }

    /**
     * @dev Blacklists an `account`, preventing it from sending or receiving tokens.
     * Only the owner can call this function.
     * @param account The address to blacklist.
     */
    function blacklist(address account) public onlyOwner {
        require(account != address(0), "Blacklist: zero address");
        require(!_isBlacklisted[account], "Blacklist: account already blacklisted");
        _isBlacklisted[account] = true;
        emit Blacklisted(account);
    }

    /**
     * @dev Unblacklists an `account`, allowing it to send and receive tokens again.
     * Only the owner can call this function.
     * @param account The address to unblacklist.
     */
    function unblacklist(address account) public onlyOwner {
        require(account != address(0), "Unblacklist: zero address");
        require(_isBlacklisted[account], "Unblacklist: account not blacklisted");
        _isBlacklisted[account] = false;
        emit Unblacklisted(account);
    }

    // --- Overrides for combined functionality ---

    /**
     * @dev See {ERC20-_beforeTokenTransfer}.
     * This override integrates Pausable and Blacklist checks.
     * It ensures that transfers only happen when not paused and
     * neither the sender nor the receiver is blacklisted.
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        override(ERC20, Pausable)
    {
        // Apply Pausable check first
        super._beforeTokenTransfer(from, to, amount);

        // Blacklist checks
        if (from != address(0)) { // Exclude address(0) for minting
            require(!_isBlacklisted[from], "ERC20: sender blacklisted");
        }
        if (to != address(0)) { // Exclude address(0) for burning
            require(!_isBlacklisted[to], "ERC20: receiver blacklisted");
        }
    }
}