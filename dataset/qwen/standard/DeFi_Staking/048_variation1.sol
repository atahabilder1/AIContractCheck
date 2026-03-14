// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract LiquidStaking is Ownable {
    IERC20 public immutable stakingToken;
    ERC20 public immutable stToken;

    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);

    constructor(address _stakingToken, string memory _stTokenName, string memory _stTokenSymbol) {
        stakingToken = IERC20(_stakingToken);
        stToken = new ERC20(_stTokenName, _stTokenSymbol);
    }

    function stake(uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0");
        stakingToken.transferFrom(msg.sender, address(this), amount);
        stToken.mint(msg.sender, amount);
        emit Staked(msg.sender, amount);
    }

    function unstake(uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0");
        stToken.burnFrom(msg.sender, amount);
        stakingToken.transfer(msg.sender, amount);
        emit Unstaked(msg.sender, amount);
    }
}

contract ERC20 is ERC20Burnable {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
}

contract ERC20Burnable is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function burnFrom(address account, uint256 amount) public virtual {
        uint256 currentAllowance = allowance(account, _msgSender());
        require(currentAllowance >= amount, "ERC20: burn amount exceeds allowance");
        unchecked {
            _approve(account, _msgSender(), currentAllowance - amount);
        }
        _burn(account, amount);
    }
}