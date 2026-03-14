// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract YieldAggregator is Ownable, Pausable {

    address[] public supportedTokens;
    mapping(address => bool) public isSupportedToken;

    event TokenSupported(address indexed tokenAddress);
    event TokenUnsupported(address indexed tokenAddress);
    event Deposit(address indexed user, address indexed token, uint256 amount);
    event Withdrawal(address indexed user, address indexed token, uint256 amount);
    event EmergencyWithdrawal(address indexed token, uint256 amount);

    modifier onlySupportedToken(address _tokenAddress) {
        require(isSupportedToken[_tokenAddress], "YieldAggregator: Token not supported");
        _;
    }

    function supportToken(address _tokenAddress) public onlyOwner {
        require(_tokenAddress != address(0), "YieldAggregator: Invalid token address");
        if (!isSupportedToken[_tokenAddress]) {
            supportedTokens.push(_tokenAddress);
            isSupportedToken[_tokenAddress] = true;
            emit TokenSupported(_tokenAddress);
        }
    }

    function unsupportToken(address _tokenAddress) public onlyOwner {
        require(_tokenAddress != address(0), "YieldAggregator: Invalid token address");
        if (isSupportedToken[_tokenAddress]) {
            // Remove from supportedTokens array (inefficient but simple for demonstration)
            for (uint i = 0; i < supportedTokens.length; i++) {
                if (supportedTokens[i] == _tokenAddress) {
                    supportedTokens[i] = supportedTokens[supportedTokens.length - 1];
                    supportedTokens.pop();
                    break;
                }
            }
            isSupportedToken[_tokenAddress] = false;
            emit TokenUnsupported(_tokenAddress);
        }
    }

    function deposit(address _tokenAddress, uint256 _amount) public whenNotPaused onlySupportedToken(_tokenAddress) {
        require(_amount > 0, "YieldAggregator: Deposit amount must be greater than zero");
        IERC20 token = IERC20(_tokenAddress);
        require(token.transferFrom(msg.sender, address(this), _amount), "YieldAggregator: Token transfer failed");
        emit Deposit(msg.sender, _tokenAddress, _amount);
    }

    function withdraw(address _tokenAddress, uint256 _amount) public whenNotPaused onlySupportedToken(_tokenAddress) {
        require(_amount > 0, "YieldAggregator: Withdrawal amount must be greater than zero");
        IERC20 token = IERC20(_tokenAddress);
        uint256 balance = token.balanceOf(address(this));
        require(_amount <= balance, "YieldAggregator: Insufficient contract balance");
        require(token.transfer(msg.sender, _amount), "YieldAggregator: Token transfer failed");
        emit Withdrawal(msg.sender, _tokenAddress, _amount);
    }

    function withdrawAllFunds(address _tokenAddress) public onlyOwner {
        require(_tokenAddress != address(0), "YieldAggregator: Invalid token address");
        IERC20 token = IERC20(_tokenAddress);
        uint256 balance = token.balanceOf(address(this));
        require(balance > 0, "YieldAggregator: No funds to withdraw");
        require(token.transfer(owner(), balance), "YieldAggregator: Token transfer failed");
        emit EmergencyWithdrawal(_tokenAddress, balance);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function getSupportedTokens() public view returns (address[] memory) {
        return supportedTokens;
    }

    function getContractTokenBalance(address _tokenAddress) public view onlySupportedToken(_tokenAddress) returns (uint256) {
        return IERC20(_tokenAddress).balanceOf(address(this));
    }
}