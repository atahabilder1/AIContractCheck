// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract CrowdfundingBondingCurve is Ownable {
    using SafeMath for uint256;

    IERC20 public immutable paymentToken;
    string public constant NAME = "BondedCrowdfund";
    string public constant SYMBOL = "BCF";

    uint256 public totalContribution;
    uint256 public totalTokensMinted;
    uint256 public constant INITIAL_PRICE = 1000; // Wei per token
    uint256 public constant PRICE_INCREASE_FACTOR = 100; // Wei increase per token

    mapping(address => uint256) public contributions;
    mapping(address => uint256) public tokensHeld;

    event Contribution(address indexed contributor, uint256 amount, uint256 tokensReceived);
    event TokenRedeemed(address indexed redeemer, uint256 amount, uint256 tokensBurned);
    event Withdrawal(address indexed recipient, uint256 amount);

    constructor(address _paymentToken) {
        paymentToken = IERC20(_paymentToken);
    }

    function getTokenPrice() public view returns (uint256) {
        if (totalTokensMinted == 0) {
            return INITIAL_PRICE;
        }
        // Price increases linearly with the number of tokens minted
        return INITIAL_PRICE.add(totalTokensMinted.mul(PRICE_INCREASE_FACTOR));
    }

    function contribute() public payable {
        require(msg.value > 0, "Contribution must be greater than zero.");

        uint256 amountSent = msg.value;
        totalContribution = totalContribution.add(amountSent);

        uint256 currentTokenPrice = getTokenPrice();
        uint256 tokensToMint = amountSent.div(currentTokenPrice);
        require(tokensToMint > 0, "Not enough contribution for any tokens.");

        totalTokensMinted = totalTokensMinted.add(tokensToMint);
        tokensHeld[msg.sender] = tokensHeld[msg.sender].add(tokensToMint);
        contributions[msg.sender] = contributions[msg.sender].add(amountSent);

        emit Contribution(msg.sender, amountSent, tokensToMint);
    }

    function contributeWithToken(uint256 _amount) public {
        require(_amount > 0, "Contribution amount must be greater than zero.");

        paymentToken.transferFrom(msg.sender, address(this), _amount);

        uint256 currentTokenPrice = getTokenPrice();
        uint256 tokensToMint = _amount.div(currentTokenPrice);
        require(tokensToMint > 0, "Not enough contribution for any tokens.");

        totalTokensMinted = totalTokensMinted.add(tokensToMint);
        tokensHeld[msg.sender] = tokensHeld[msg.sender].add(tokensToMint);
        contributions[msg.sender] = contributions[msg.sender].add(_amount); // Track contribution in token terms

        emit Contribution(msg.sender, _amount, tokensToMint);
    }

    function redeemTokens(uint256 _amountOfTokens) public {
        require(_amountOfTokens > 0, "Amount of tokens to redeem must be greater than zero.");
        require(tokensHeld[msg.sender] >= _amountOfTokens, "Not enough tokens to redeem.");

        // Calculate the price at which these tokens were originally bought.
        // This is tricky with a simple linear bonding curve.
        // For a true bonding curve, you'd need a more complex curve function
        // and potentially a redemption mechanism that burns tokens and refunds Ether.
        // This simplified version assumes redemption is based on the *current* price,
        // which means early contributors might get less back than they put in if the price
        // has increased significantly, or more back if the price has decreased (which isn't possible with this curve).
        // A more robust bonding curve would have a redemption price tied to the purchase price.

        // For this example, we'll simulate a redemption by burning tokens and refunding based on the current total contribution.
        // This is NOT a typical bonding curve redemption. A proper bonding curve requires a mathematical function
        // that relates token supply to reserve value.

        // In a real bonding curve, you'd calculate the refund based on the reserve and the number of tokens.
        // Example of a simplified redemption for demonstration purposes:
        // If totalContribution is the reserve, and totalTokensMinted are the tokens,
        // the value per token is totalContribution / totalTokensMinted.

        uint256 currentReserveValue = address(this).balance; // Assuming ETH is the reserve for this example
        if (paymentToken != IERC20(0)) {
            currentReserveValue = paymentToken.balanceOf(address(this));
        }

        uint256 valuePerToken = 0;
        if (totalTokensMinted > 0) {
            valuePerToken = currentReserveValue.div(totalTokensMinted);
        }

        uint256 refundAmount = _amountOfTokens.mul(valuePerToken);
        require(refundAmount > 0, "Refund amount is zero.");

        tokensHeld[msg.sender] = tokensHeld[msg.sender].sub(_amountOfTokens);
        totalTokensMinted = totalTokensMinted.sub(_amountOfTokens);

        if (paymentToken == IERC20(0)) { // ETH crowdfunding
            (payable(msg.sender)).transfer(refundAmount);
        } else { // ERC20 token crowdfunding
            paymentToken.transfer(msg.sender, refundAmount);
        }

        emit TokenRedeemed(msg.sender, refundAmount, _amountOfTokens);
    }

    function withdrawFunds() public onlyOwner {
        uint256 balance = address(this).balance;
        if (paymentToken == IERC20(0)) { // ETH crowdfunding
            (payable(owner())).transfer(balance);
            emit Withdrawal(owner(), balance);
        } else { // ERC20 token crowdfunding
            uint256 tokenBalance = paymentToken.balanceOf(address(this));
            paymentToken.transfer(owner(), tokenBalance);
            emit Withdrawal(owner(), tokenBalance);
        }
    }

    receive() external payable {
        contribute();
    }
}