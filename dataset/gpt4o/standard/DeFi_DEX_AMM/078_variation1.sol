// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    function transfer(address to, uint256 value) external returns (bool);
    function balanceOf(address who) external view returns (uint256);
}

contract SimpleOrderBookDEX {
    struct Order {
        address trader;
        uint256 amount;
        uint256 price;
        bool isBuy; // true for buy, false for sell
    }

    mapping(address => mapping(address => Order[])) public orderBook; // token pair => orders
    mapping(address => mapping(address => uint256)) public balances; // token => user => balance

    function deposit(address token, uint256 amount) external {
        require(IERC20(token).transferFrom(msg.sender, address(this), amount), "Deposit failed");
        balances[token][msg.sender] += amount;
    }

    function withdraw(address token, uint256 amount) external {
        require(balances[token][msg.sender] >= amount, "Insufficient balance");
        balances[token][msg.sender] -= amount;
        require(IERC20(token).transfer(msg.sender, amount), "Withdraw failed");
    }

    function placeOrder(address baseToken, address quoteToken, uint256 amount, uint256 price, bool isBuy) external {
        if (isBuy) {
            require(balances[quoteToken][msg.sender] >= amount * price, "Insufficient quote balance");
            balances[quoteToken][msg.sender] -= amount * price;
        } else {
            require(balances[baseToken][msg.sender] >= amount, "Insufficient base balance");
            balances[baseToken][msg.sender] -= amount;
        }
        orderBook[baseToken][quoteToken].push(Order(msg.sender, amount, price, isBuy));
    }

    function matchOrders(address baseToken, address quoteToken) external {
        Order[] storage orders = orderBook[baseToken][quoteToken];
        for (uint256 i = 0; i < orders.length; i++) {
            for (uint256 j = i + 1; j < orders.length; j++) {
                if (orders[i].isBuy != orders[j].isBuy && orders[i].price == orders[j].price) {
                    uint256 tradeAmount = min(orders[i].amount, orders[j].amount);
                    orders[i].amount -= tradeAmount;
                    orders[j].amount -= tradeAmount;

                    if (orders[i].isBuy) {
                        balances[baseToken][orders[i].trader] += tradeAmount;
                        balances[quoteToken][orders[j].trader] += tradeAmount * orders[i].price;
                    } else {
                        balances[baseToken][orders[j].trader] += tradeAmount;
                        balances[quoteToken][orders[i].trader] += tradeAmount * orders[i].price;
                    }

                    if (orders[i].amount == 0) {
                        removeOrder(orders, i);
                        i--;
                        break;
                    }
                    if (orders[j].amount == 0) {
                        removeOrder(orders, j);
                        j--;
                    }
                }
            }
        }
    }

    function removeOrder(Order[] storage orders, uint256 index) internal {
        orders[index] = orders[orders.length - 1];
        orders.pop();
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
}