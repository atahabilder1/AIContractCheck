// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract CrowdfundingICO {
    address public immutable owner;
    uint256 public immutable goal;
    uint256 public immutable deadline;
    uint256 public immutable tokenPrice;
    uint256 public totalRaised;
    bool public finalized;

    mapping(address => uint256) public contributions;
    mapping(address => uint256) public tokenBalances;

    string public constant name = "CrowdfundToken";
    string public constant symbol = "CFT";
    uint8 public constant decimals = 18;
    uint256 public totalSupply;

    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Contribution(address indexed contributor, uint256 amount, uint256 tokens);
    event Refund(address indexed contributor, uint256 amount);
    event Finalized(uint256 totalRaised, bool goalReached);

    constructor(uint256 _goal, uint256 _durationDays, uint256 _tokenPrice) {
        owner = msg.sender;
        goal = _goal;
        deadline = block.timestamp + _durationDays * 1 days;
        tokenPrice = _tokenPrice;
    }

    function contribute() external payable {
        require(block.timestamp < deadline, "ended");
        require(msg.value > 0, "zero");

        contributions[msg.sender] += msg.value;
        totalRaised += msg.value;

        uint256 tokens = (msg.value * 1e18) / tokenPrice;
        tokenBalances[msg.sender] += tokens;
        totalSupply += tokens;

        emit Contribution(msg.sender, msg.value, tokens);
        emit Transfer(address(0), msg.sender, tokens);
    }

    function finalize() external {
        require(!finalized, "done");
        require(block.timestamp >= deadline || totalRaised >= goal, "active");
        finalized = true;

        emit Finalized(totalRaised, totalRaised >= goal);

        if (totalRaised >= goal) {
            (bool s,) = owner.call{value: address(this).balance}("");
            require(s);
        }
    }

    function refund() external {
        require(finalized && totalRaised < goal, "no refund");
        uint256 amount = contributions[msg.sender];
        require(amount > 0, "nothing");

        uint256 tokens = tokenBalances[msg.sender];
        contributions[msg.sender] = 0;
        tokenBalances[msg.sender] = 0;
        totalSupply -= tokens;

        emit Refund(msg.sender, amount);
        emit Transfer(msg.sender, address(0), tokens);

        (bool s,) = msg.sender.call{value: amount}("");
        require(s);
    }

    function transfer(address to, uint256 value) external returns (bool) {
        require(finalized && totalRaised >= goal, "locked");
        tokenBalances[msg.sender] -= value;
        tokenBalances[to] += value;
        emit Transfer(msg.sender, to, value);
        return true;
    }

    function approve(address spender, uint256 value) external returns (bool) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) external returns (bool) {
        require(finalized && totalRaised >= goal, "locked");
        allowance[from][msg.sender] -= value;
        tokenBalances[from] -= value;
        tokenBalances[to] += value;
        emit Transfer(from, to, value);
        return true;
    }

    function balanceOf(address account) external view returns (uint256) {
        return tokenBalances[account];
    }

    function timeLeft() external view returns (uint256) {
        return block.timestamp >= deadline ? 0 : deadline - block.timestamp;
    }

    receive() external payable {
        require(block.timestamp < deadline && msg.value > 0);
        contributions[msg.sender] += msg.value;
        totalRaised += msg.value;
        uint256 tokens = (msg.value * 1e18) / tokenPrice;
        tokenBalances[msg.sender] += tokens;
        totalSupply += tokens;
        emit Contribution(msg.sender, msg.value, tokens);
        emit Transfer(address(0), msg.sender, tokens);
    }
}