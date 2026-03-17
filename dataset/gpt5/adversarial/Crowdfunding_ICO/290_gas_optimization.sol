// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MinimalICO {
    // ERC20
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    // Sale
    address public immutable wallet;      // destination for raised ETH
    uint256 public immutable rate;        // tokens per wei

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(string memory name_, string memory symbol_, address wallet_, uint256 rate_) {
        name = name_;
        symbol = symbol_;
        wallet = wallet_;
        rate = rate_;
    }

    // Purchase: mints tokens and forwards ETH
    function buy() public payable {
        uint256 amount = msg.value * rate;
        if (amount != 0) {
            totalSupply += amount;
            balanceOf[msg.sender] += amount;
            emit Transfer(address(0), msg.sender, amount);
        }
        (bool s, ) = wallet.call{value: msg.value}("");
        require(s);
    }

    receive() external payable { buy(); }
    fallback() external payable { buy(); }

    // ERC20
    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        uint256 bal = balanceOf[msg.sender];
        require(bal >= amount);
        unchecked { balanceOf[msg.sender] = bal - amount; }
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            require(allowed >= amount);
            unchecked { allowance[from][msg.sender] = allowed - amount; }
        }
        uint256 bal = balanceOf[from];
        require(bal >= amount);
        unchecked { balanceOf[from] = bal - amount; }
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
        return true;
    }
}