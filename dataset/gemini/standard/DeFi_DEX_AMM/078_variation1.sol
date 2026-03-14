// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract OrderBookDEX is Ownable {
    using SafeMath for uint256;

    struct Order {
        uint256 id;
        address maker;
        address taker; // 0x0 for open orders
        address baseToken;
        address quoteToken;
        uint256 amount;
        uint256 price; // price in quote token per base token
        uint256 timestamp;
        bool isBuy;
        bool filled;
    }

    uint256 public nextOrderId;

    // Mapping from order ID to order details
    mapping(uint256 => Order) public orders;

    // Orders organized by token pair and order type (buy/sell)
    // baseToken -> quoteToken -> isBuy -> price -> order ID
    mapping(address => mapping(address => mapping(bool => mapping(uint256 => bytes)))) public orderBook;

    // Event for new orders
    event OrderPlaced(
        uint256 indexed orderId,
        address indexed maker,
        address indexed baseToken,
        address indexed quoteToken,
        uint256 amount,
        uint256 price,
        bool isBuy
    );

    // Event for order fills
    event OrderFilled(
        uint256 indexed orderId,
        address indexed maker,
        address indexed taker,
        uint256 filledAmount,
        uint256 remainingAmount
    );

    // Event for order cancellation
    event OrderCancelled(
        uint256 indexed orderId,
        address indexed maker
    );

    // Function to add a new order to the order book
    function placeOrder(
        address baseToken,
        address quoteToken,
        uint256 amount,
        uint256 price, // price in quote token per base token
        bool isBuy
    ) public {
        require(baseToken != address(0) && quoteToken != address(0), "Invalid token addresses");
        require(amount > 0, "Amount must be greater than zero");
        require(price > 0, "Price must be greater than zero");

        uint256 orderId = nextOrderId++;
        orders[orderId] = Order({
            id: orderId,
            maker: msg.sender,
            taker: address(0),
            baseToken: baseToken,
            quoteToken: quoteToken,
            amount: amount,
            price: price,
            timestamp: block.timestamp,
            isBuy: isBuy,
            filled: false
        });

        // Add order to the order book data structure
        bytes memory orderIdBytes = abi.encodePacked(orderId);
        orderBook[baseToken][quoteToken][isBuy][price] = appendBytes(orderBook[baseToken][quoteToken][isBuy][price], orderIdBytes);

        emit OrderPlaced(orderId, msg.sender, baseToken, quoteToken, amount, price, isBuy);
    }

    // Function to fill an existing order
    function fillOrder(uint256 orderId, uint256 amountToFill) public {
        Order storage order = orders[orderId];
        require(order.id != 0, "Order does not exist");
        require(order.taker == address(0), "Order already taken"); // Only open orders can be filled
        require(!order.filled, "Order already filled");
        require(order.maker != msg.sender, "Cannot fill your own order");
        require(amountToFill > 0, "Amount to fill must be greater than zero");

        uint256 availableAmount = order.amount;
        uint256 actualAmountToFill = amountToFill < availableAmount ? amountToFill : availableAmount;
        require(actualAmountToFill > 0, "No amount to fill");

        // Determine the tokens to transfer
        address fromToken;
        address toToken;
        uint256 amountInFromToken;
        uint256 amountInToToken;

        if (order.isBuy) { // Maker is buying baseToken with quoteToken
            fromToken = order.quoteToken; // Taker sends quoteToken
            toToken = order.baseToken;    // Taker receives baseToken
            amountInFromToken = actualAmountToFill.mul(order.price); // Taker sends quoteToken amount
            amountInToToken = actualAmountToFill;                    // Taker receives baseToken amount

            // Transfer quoteToken from taker to maker
            IERC20(fromToken).transferFrom(msg.sender, order.maker, amountInFromToken);
            // Transfer baseToken from maker to taker
            IERC20(toToken).transferFrom(order.maker, msg.sender, amountInToToken);
        } else { // Maker is selling baseToken for quoteToken
            fromToken = order.baseToken; // Taker sends baseToken
            toToken = order.quoteToken;  // Taker receives quoteToken
            amountInFromToken = actualAmountToFill;                    // Taker sends baseToken amount
            amountInToToken = actualAmountToFill.mul(order.price); // Taker receives quoteToken amount

            // Transfer baseToken from taker to maker
            IERC20(fromToken).transferFrom(msg.sender, order.maker, amountInFromToken);
            // Transfer quoteToken from maker to taker
            IERC20(toToken).transferFrom(order.maker, msg.sender, amountInToToken);
        }

        // Update order status
        order.amount = order.amount.sub(actualAmountToFill);
        if (order.amount == 0) {
            order.filled = true;
        }

        emit OrderFilled(orderId, order.maker, msg.sender, actualAmountToFill, order.amount);
    }

    // Function to cancel an order
    function cancelOrder(uint256 orderId) public {
        Order storage order = orders[orderId];
        require(order.id != 0, "Order does not exist");
        require(order.maker == msg.sender, "Only the maker can cancel their order");
        require(!order.filled, "Cannot cancel a filled order");

        // Remove order from the order book data structure
        removeOrderIdFromOrderBook(order.baseToken, order.quoteToken, order.isBuy, order.price, orderId);

        // Mark order as filled to prevent further interaction
        order.filled = true;

        emit OrderCancelled(orderId, msg.sender);
    }

    // Helper function to append bytes
    function appendBytes(bytes memory _destination, bytes memory _source) internal pure returns (bytes memory) {
        return bytes.concat(_destination, _source);
    }

    // Helper function to remove an order ID from the order book
    function removeOrderIdFromOrderBook(address baseToken, address quoteToken, bool isBuy, uint256 price, uint256 orderIdToRemove) internal {
        bytes memory currentOrdersBytes = orderBook[baseToken][quoteToken][isBuy][price];
        bytes memory updatedOrdersBytes = abi.encodePacked(bytes("")); // Initialize with empty bytes

        uint256 currentIndex = 0;
        while (currentIndex < currentOrdersBytes.length) {
            // Each order ID is encoded as a uint256, which is 32 bytes
            // We need to decode it to compare
            uint256 currentOrderId;
            assembly {
                currentOrderId := mload(add(currentOrdersBytes, add(32, currentIndex)))
            }

            if (currentOrderId != orderIdToRemove) {
                bytes memory orderIdBytes = abi.encodePacked(uint256(currentOrderId));
                updatedOrdersBytes = appendBytes(updatedOrdersBytes, orderIdBytes);
            }

            currentIndex = currentIndex.add(32); // Move to the next 32-byte chunk
        }

        orderBook[baseToken][quoteToken][isBuy][price] = updatedOrdersBytes;
    }

    // Function to get all open order IDs for a given pair and price
    function getOpenOrders(address baseToken, address quoteToken, bool isBuy, uint256 price) public view returns (uint256[] memory) {
        bytes memory orderIdsBytes = orderBook[baseToken][quoteToken][isBuy][price];
        uint256 count = orderIdsBytes.length / 32; // Each order ID is 32 bytes
        uint256[] memory orderIds = new uint256[](count);

        for (uint256 i = 0; i < count; i++) {
            uint256 orderId;
            assembly {
                orderId := mload(add(orderIdsBytes, add(32, mul(i, 32))))
            }
            orderIds[i] = orderId;
        }
        return orderIds;
    }

    // Function to get order details by ID
    function getOrder(uint256 orderId) public view returns (Order memory) {
        return orders[orderId];
    }
}