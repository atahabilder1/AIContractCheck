// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
}

contract OrderBookDEX {
    enum Side { Buy, Sell }

    struct Order {
        uint256 id;
        address trader;
        Side side;
        address baseToken;
        address quoteToken;
        uint256 price;
        uint256 amount;
        uint256 filled;
    }

    uint256 public nextOrderId = 1;

    mapping(uint256 => Order) public orders;
    mapping(address => uint256[]) public userOrders;

    // pair hash => side => order IDs
    mapping(bytes32 => mapping(Side => uint256[])) public orderBook;

    event OrderPlaced(uint256 indexed id, address indexed trader, Side side, address baseToken, address quoteToken, uint256 price, uint256 amount);
    event OrderCancelled(uint256 indexed id);
    event Trade(uint256 indexed buyOrderId, uint256 indexed sellOrderId, uint256 amount, uint256 price);

    function pairHash(address baseToken, address quoteToken) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(baseToken, quoteToken));
    }

    function placeBuyOrder(address baseToken, address quoteToken, uint256 price, uint256 amount) external {
        require(price > 0 && amount > 0, "Invalid price or amount");

        uint256 quoteAmount = (amount * price) / 1e18;
        require(IERC20(quoteToken).transferFrom(msg.sender, address(this), quoteAmount), "Quote transfer failed");

        uint256 id = nextOrderId++;
        orders[id] = Order(id, msg.sender, Side.Buy, baseToken, quoteToken, price, amount, 0);
        userOrders[msg.sender].push(id);

        bytes32 ph = pairHash(baseToken, quoteToken);
        _matchBuyOrder(id, ph);

        if (orders[id].filled < orders[id].amount) {
            orderBook[ph][Side.Buy].push(id);
        }

        emit OrderPlaced(id, msg.sender, Side.Buy, baseToken, quoteToken, price, amount);
    }

    function placeSellOrder(address baseToken, address quoteToken, uint256 price, uint256 amount) external {
        require(price > 0 && amount > 0, "Invalid price or amount");

        require(IERC20(baseToken).transferFrom(msg.sender, address(this), amount), "Base transfer failed");

        uint256 id = nextOrderId++;
        orders[id] = Order(id, msg.sender, Side.Sell, baseToken, quoteToken, price, amount, 0);
        userOrders[msg.sender].push(id);

        bytes32 ph = pairHash(baseToken, quoteToken);
        _matchSellOrder(id, ph);

        if (orders[id].filled < orders[id].amount) {
            orderBook[ph][Side.Sell].push(id);
        }

        emit OrderPlaced(id, msg.sender, Side.Sell, baseToken, quoteToken, price, amount);
    }

    function cancelOrder(uint256 orderId) external {
        Order storage order = orders[orderId];
        require(order.trader == msg.sender, "Not your order");
        uint256 remaining = order.amount - order.filled;
        require(remaining > 0, "Already filled");

        order.filled = order.amount;

        if (order.side == Side.Buy) {
            uint256 refund = (remaining * order.price) / 1e18;
            IERC20(order.quoteToken).transfer(msg.sender, refund);
        } else {
            IERC20(order.baseToken).transfer(msg.sender, remaining);
        }

        emit OrderCancelled(orderId);
    }

    function _matchBuyOrder(uint256 buyId, bytes32 ph) internal {
        Order storage buyOrder = orders[buyId];
        uint256[] storage sellIds = orderBook[ph][Side.Sell];

        for (uint256 i = 0; i < sellIds.length && buyOrder.filled < buyOrder.amount; i++) {
            Order storage sellOrder = orders[sellIds[i]];
            uint256 sellRemaining = sellOrder.amount - sellOrder.filled;
            if (sellRemaining == 0) continue;
            if (sellOrder.price > buyOrder.price) continue;

            uint256 buyRemaining = buyOrder.amount - buyOrder.filled;
            uint256 tradeAmount = buyRemaining < sellRemaining ? buyRemaining : sellRemaining;
            uint256 tradeCost = (tradeAmount * sellOrder.price) / 1e18;
            uint256 buyerPaid = (tradeAmount * buyOrder.price) / 1e18;

            buyOrder.filled += tradeAmount;
            sellOrder.filled += tradeAmount;

            IERC20(buyOrder.baseToken).transfer(buyOrder.trader, tradeAmount);
            IERC20(buyOrder.quoteToken).transfer(sellOrder.trader, tradeCost);

            if (buyerPaid > tradeCost) {
                IERC20(buyOrder.quoteToken).transfer(buyOrder.trader, buyerPaid - tradeCost);
            }

            emit Trade(buyId, sellIds[i], tradeAmount, sellOrder.price);
        }
    }

    function _matchSellOrder(uint256 sellId, bytes32 ph) internal {
        Order storage sellOrder = orders[sellId];
        uint256[] storage buyIds = orderBook[ph][Side.Buy];

        for (uint256 i = 0; i < buyIds.length && sellOrder.filled < sellOrder.amount; i++) {
            Order storage buyOrder = orders[buyIds[i]];
            uint256 buyRemaining = buyOrder.amount - buyOrder.filled;
            if (buyRemaining == 0) continue;
            if (buyOrder.price < sellOrder.price) continue;

            uint256 sellRemaining = sellOrder.amount - sellOrder.filled;
            uint256 tradeAmount = sellRemaining < buyRemaining ? sellRemaining : buyRemaining;
            uint256 tradeCost = (tradeAmount * sellOrder.price) / 1e18;
            uint256 buyerPaid = (tradeAmount * buyOrder.price) / 1e18;

            sellOrder.filled += tradeAmount;
            buyOrder.filled += tradeAmount;

            IERC20(sellOrder.baseToken).transfer(buyOrder.trader, tradeAmount);
            IERC20(sellOrder.quoteToken).transfer(sellOrder.trader, tradeCost);

            if (buyerPaid > tradeCost) {
                IERC20(sellOrder.quoteToken).transfer(buyOrder.trader, buyerPaid - tradeCost);
            }

            emit Trade(buyIds[i], sellId, tradeAmount, sellOrder.price);
        }
    }

    function getOrderBook(address baseToken, address quoteToken, Side side) external view returns (uint256[] memory) {
        return orderBook[pairHash(baseToken, quoteToken)][side];
    }

    function getUserOrders(address user) external view returns (uint256[] memory) {
        return userOrders[user];
    }
}