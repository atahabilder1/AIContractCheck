// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract CrowdfundingICO is ERC20 {
    address public owner;
    uint256 public goal;
    uint256 public deadline;
    uint256 public tokenPrice;
    uint256 public totalRaised;
    bool public finalized;

    mapping(address => uint256) public contributions;

    event Contributed(address indexed contributor, uint256 amount, uint256 tokens);
    event Finalized(uint256 totalRaised);
    event Refunded(address indexed contributor, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _goal,
        uint256 _durationDays,
        uint256 _tokenPrice
    ) ERC20(_name, _symbol) {
        owner = msg.sender;
        goal = _goal;
        deadline = block.timestamp + (_durationDays * 1 days);
        tokenPrice = _tokenPrice;
    }

    function contribute() external payable {
        require(block.timestamp < deadline, "ICO ended");
        require(msg.value > 0, "Send ETH");
        require(!finalized, "Already finalized");

        uint256 tokens = (msg.value * 1e18) / tokenPrice;
        contributions[msg.sender] += msg.value;
        totalRaised += msg.value;

        _mint(msg.sender, tokens);
        emit Contributed(msg.sender, msg.value, tokens);
    }

    function finalize() external onlyOwner {
        require(block.timestamp >= deadline || totalRaised >= goal, "Not ready");
        require(!finalized, "Already finalized");

        finalized = true;

        if (totalRaised >= goal) {
            (bool sent, ) = owner.call{value: address(this).balance}("");
            require(sent, "Transfer failed");
        }

        emit Finalized(totalRaised);
    }

    function refund() external {
        require(finalized, "Not finalized");
        require(totalRaised < goal, "Goal met");

        uint256 amount = contributions[msg.sender];
        require(amount > 0, "No contribution");

        contributions[msg.sender] = 0;

        (bool sent, ) = msg.sender.call{value: amount}("");
        require(sent, "Refund failed");

        emit Refunded(msg.sender, amount);
    }

    receive() external payable {
        revert("Use contribute()");
    }
}