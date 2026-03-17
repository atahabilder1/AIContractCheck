// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract WrappedToken {
    string public constant name = "Wrapped Token";
    string public constant symbol = "WTKN";
    uint8 public constant decimals = 18;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Deposit(address indexed dst, uint256 wad);
    event Withdrawal(address indexed src, uint256 wad);

    function totalSupply() external view returns (uint256) {
        return address(this).balance;
    }

    function approve(address spender, uint256 value) external returns (bool) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function transfer(address to, uint256 value) external returns (bool) {
        return transferFrom(msg.sender, to, value);
    }

    function transferFrom(address from, address to, uint256 value) public returns (bool) {
        require(balanceOf[from] >= value);
        unchecked {
            balanceOf[from] -= value;
            balanceOf[to] += value;
        }

        if (from != msg.sender) {
            uint256 allowed = allowance[from][msg.sender];
            if (allowed != type(uint256).max) {
                require(allowed >= value);
                unchecked {
                    allowance[from][msg.sender] = allowed - value;
                }
            }
        }

        emit Transfer(from, to, value);
        return true;
    }

    function deposit() public payable {
        unchecked {
            balanceOf[msg.sender] += msg.value;
        }
        emit Deposit(msg.sender, msg.value);
        emit Transfer(address(0), msg.sender, msg.value);
    }

    receive() external payable {
        deposit();
    }

    function withdraw(uint256 value) external {
        require(balanceOf[msg.sender] >= value);
        unchecked {
            balanceOf[msg.sender] -= value;
        }
        (bool ok, ) = msg.sender.call{value: value}("");
        require(ok);
        emit Withdrawal(msg.sender, value);
        emit Transfer(msg.sender, address(0), value);
    }
}