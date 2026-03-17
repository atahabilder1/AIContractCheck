// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SimpleOrderBookDEX {
    struct Order {
        address owner;
        uint256 amount;
        uint256 price;
    }

    IERC20 public tokenA;
    IERC20 public tokenB;
    mapping(uint256 => Order[]) public buyOrders;
    mapping(uint256 => Order[]) public sellOrders;

    constructor(IERC20 _tokenA, IERC20 _tokenB) {
        tokenA = _tokenA;
        tokenB = _tokenB;
    }

    function placeBuyOrder(uint256 amount, uint256 price) public {
        buyOrders[price].push(Order(msg.sender, amount, price));
    }

    function placeSellOrder(uint256 amount, uint256 price) public {
        sellOrders[price].push(Order(msg.sender, amount, price));
    }

    function matchOrders() public {
        for (uint256 i = 0; i < sellOrders.length; i++) {
            if (sellOrders[i][0].price <= buyOrders[buyOrders.length - 1].price) {
                _executeTrade(sellOrders[i][0], buyOrders[buyOrders.length - 1]);
                sellOrders[i] = sellOrders[i][1:];
            } else {
                break;
            }
        }
    }

    function _executeTrade(Order memory seller, Order memory buyer) private {
        uint256 tradeAmount = min(seller.amount, buyer.amount);
        tokenA.transferFrom(buyer.owner, address(this), tradeAmount * buyer.price);
        tokenB.transferFrom(address(this), seller.owner, tradeAmount);
        if (seller.amount == tradeAmount) {
            delete sellOrders[seller.price][0];
        } else {
            sellOrders[seller.price][0].amount -= tradeAmount;
        }
        if (buyer.amount == tradeAmount) {
            buyOrders[buyer.price] = buyOrders[buyer.price][1:];
        } else {
            buyOrders[buyer.price][0].amount -= tradeAmount;
        }
    }
}