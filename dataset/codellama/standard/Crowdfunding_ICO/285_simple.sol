pragma solidity ^0.8.0;

contract Crowdfunding {
    address public owner;
    uint public goal;
    uint public deadline;
    uint public totalContributions;
    mapping(address => uint) public contributions;

    constructor(uint _goal, uint _deadline) public {
        owner = msg.sender;
        goal = _goal;
        deadline = _deadline;
    }

    function contribute() public payable {
        require(msg.value > 0, "Invalid contribution amount");
        require(now <= deadline, "Campaign has ended");
        contributions[msg.sender] += msg.value;
        totalContributions += msg.value;
    }

    function refund() public {
        require(totalContributions < goal, "Campaign has not been completed");
        require(now > deadline, "Campaign has not ended yet");
        uint amount = contributions[msg.sender];
        contributions[msg.sender] = 0;
        msg.sender.transfer(amount);
    }
}
```

Note: This code has not been audited and should not be used in a production environment without proper review and testing.