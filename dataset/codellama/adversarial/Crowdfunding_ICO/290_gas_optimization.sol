SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract Crowdfunding {

    // Constants
    uint public constant TOTAL_SUPPLY = 10000000000000000000000000;
    uint public constant MINIMUM_CONTRIBUTION = 1000000000000000000;
    uint public constant MAXIMUM_CONTRIBUTION = 100000000000000000000;
    uint public constant ICO_DURATION = 30 days;
    uint public constant ICO_START_TIME = block.timestamp;
    uint public constant ICO_END_TIME = ICO_START_TIME + ICO_DURATION;

    // Variables
    uint public totalContributions = 0;
    uint public totalTokensSold = 0;
    mapping(address => uint) public contributions;
    mapping(address => uint) public tokensSold;
    address public owner;

    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    modifier beforeICOStart() {
        require(block.timestamp < ICO_START_TIME);
        _;
    }

    modifier duringICO() {
        require(block.timestamp >= ICO_START_TIME && block.timestamp <= ICO_END_TIME);
        _;
    }

    modifier afterICOEnd() {
        require(block.timestamp > ICO_END_TIME);
        _;
    }

    // Constructor
    constructor() public {
        owner = msg.sender;
    }

    // Functions
    function contribute() public payable beforeICOStart {
        require(msg.value >= MINIMUM_CONTRIBUTION);
        require(msg.value <= MAXIMUM_CONTRIBUTION);
        contributions[msg.sender] += msg.value;
        totalContributions += msg.value;
    }

    function buyTokens() public payable duringICO {
        require(msg.value >= MINIMUM_CONTRIBUTION);
        require(msg.value <= MAXIMUM_CONTRIBUTION);
        uint tokens = msg.value * 100000000;
        require(tokensSold + tokens <= TOTAL_SUPPLY);
        tokensSold[msg.sender] += tokens;
        totalTokensSold += tokens;
        owner.transfer(msg.value);
    }

    function withdraw() public afterICOEnd {
        require(msg.sender == owner);
        require(address(this).balance > 0);
        owner.transfer(address(this).balance);
    }

    function transfer(address _to, uint _value) public onlyOwner {
        require(_value <= address(this).balance);
        _to.transfer(_value);
    }

    function getBalance() public view returns (uint) {
        return address(this).balance;
    }

    function getTotalContributions() public view returns (uint) {
        return totalContributions;
    }

    function getTotalTokensSold() public view returns (uint) {
        return totalTokensSold;
    }

    function getContributions() public view returns (mapping(address => uint)) {
        return contributions;
    }

    function getTokensSold() public view returns (mapping(address => uint)) {
        return tokensSold;
    }
}