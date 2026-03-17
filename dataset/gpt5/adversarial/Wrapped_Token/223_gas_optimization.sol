// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract WrappedToken {
    // ERC-20 events
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Transfer(address indexed from, address indexed to, uint256 value);

    // Custom errors
    error InsufficientBalance();
    error InsufficientAllowance();
    error EthTransferFailed();

    // ERC-20 metadata (no storage used)
    function name() external pure returns (string memory) { return "Wrapped Ether"; }
    function symbol() external pure returns (string memory) { return "WETH"; }
    function decimals() external pure returns (uint8) { return 18; }

    // ERC-20 storage
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    // Wrap ETH
    function deposit() external payable {
        uint256 wad = msg.value;
        unchecked {
            balanceOf[msg.sender] += wad;
            totalSupply += wad;
        }
        emit Transfer(address(0), msg.sender, wad);
    }

    // Unwrap ETH
    function withdraw(uint256 wad) external {
        if (balanceOf[msg.sender] < wad) revert InsufficientBalance();
        unchecked {
            balanceOf[msg.sender] -= wad;
            totalSupply -= wad;
        }
        (bool ok, ) = msg.sender.call{value: wad}("");
        if (!ok) revert EthTransferFailed();
        emit Transfer(msg.sender, address(0), wad);
    }

    // ERC-20 approve
    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    // ERC-20 transfer
    function transfer(address to, uint256 amount) external returns (bool) {
        if (balanceOf[msg.sender] < amount) revert InsufficientBalance();
        unchecked {
            balanceOf[msg.sender] -= amount;
            balanceOf[to] += amount;
        }
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    // ERC-20 transferFrom
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        if (balanceOf[from] < amount) revert InsufficientBalance();

        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            if (allowed < amount) revert InsufficientAllowance();
            unchecked {
                allowance[from][msg.sender] = allowed - amount;
            }
            emit Approval(from, msg.sender, allowance[from][msg.sender]);
        }

        unchecked {
            balanceOf[from] -= amount;
            balanceOf[to] += amount;
        }
        emit Transfer(from, to, amount);
        return true;
    }

    // Accept ETH via receive/fallback and mint
    receive() external payable {
        uint256 wad = msg.value;
        unchecked {
            balanceOf[msg.sender] += wad;
            totalSupply += wad;
        }
        emit Transfer(address(0), msg.sender, wad);
    }

    fallback() external payable {
        if (msg.value == 0) return;
        uint256 wad = msg.value;
        unchecked {
            balanceOf[msg.sender] += wad;
            totalSupply += wad;
        }
        emit Transfer(address(0), msg.sender, wad);
    }
}