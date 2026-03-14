// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract YieldAggregator {
    struct Vault {
        address token;
        uint256 balance;
    }

    mapping(address => Vault) public vaults;
    mapping(address => mapping(address => uint256)) public deposits;

    event Deposit(address indexed user, address indexed token, uint256 amount);
    event Withdraw(address indexed user, address indexed token, uint256 amount);

    function deposit(address _token, uint256 _amount) external {
        require(_amount > 0, "Amount must be greater than zero");
        require(IERC20(_token).transferFrom(msg.sender, address(this), _amount), "Transfer failed");

        deposits[msg.sender][_token] += _amount;
        vaults[_token].balance += _amount;

        emit Deposit(msg.sender, _token, _amount);
    }

    function withdraw(address _token, uint256 _amount) external {
        require(_amount > 0, "Amount must be greater than zero");
        require(deposits[msg.sender][_token] >= _amount, "Insufficient balance");

        deposits[msg.sender][_token] -= _amount;
        vaults[_token].balance -= _amount;

        require(IERC20(_token).transfer(msg.sender, _amount), "Transfer failed");

        emit Withdraw(msg.sender, _token, _amount);
    }

    function getVaultBalance(address _token) external view returns (uint256) {
        return vaults[_token].balance;
    }

    function getUserDeposit(address _user, address _token) external view returns (uint256) {
        return deposits[_user][_token];
    }
}

interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
}