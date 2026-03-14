pragma solidity ^0.8.0;

contract ICO {

    address public owner;
    address public token;
    uint256 public softCap;
    uint256 public hardCap;
    uint256 public startTime;
    uint256 public endTime;
    mapping(address => uint256) public purchases;
    mapping(address => uint256) public vestingSchedules;
    mapping(address => bool) public kycVerified;

    constructor(address _owner, address _token, uint256 _softCap, uint256 _hardCap, uint256 _startTime, uint256 _endTime) public {
        owner = _owner;
        token = _token;
        softCap = _softCap;
        hardCap = _hardCap;
        startTime = _startTime;
        endTime = _endTime;
    }

    function buyTokens(address _buyer, uint256 _amount) public {
        require(msg.sender == owner, "Only the owner can buy tokens");
        require(block.timestamp >= startTime, "ICO has not started yet");
        require(block.timestamp <= endTime, "ICO has already ended");
        require(_amount > 0, "Invalid amount");
        require(purchases[_buyer] + _amount <= hardCap, "Exceeds hard cap");
        require(kycVerified[_buyer], "KYC verification required");

        purchases[_buyer] += _amount;
        vestingSchedules[_buyer] = _amount;

        // Transfer tokens to the buyer
        token.transfer(_buyer, _amount);
    }

    function refund() public {
        require(msg.sender == owner, "Only the owner can refund");
        require(block.timestamp > endTime, "ICO has not ended yet");
        require(purchases[msg.sender] > 0, "No tokens purchased");

        uint256 amount = purchases[msg.sender];
        purchases[msg.sender] = 0;

        // Transfer tokens back to the owner
        token.transfer(msg.sender, amount);
    }

    function verifyKYC(address _buyer) public {
        require(msg.sender == owner, "Only the owner can verify KYC");
        require(!kycVerified[_buyer], "KYC already verified");

        kycVerified[_buyer] = true;
    }

    function getTokensSold() public view returns (uint256) {
        return token.balanceOf(address(this));
    }

    function getSoftCapReached() public view returns (bool) {
        return token.balanceOf(address(this)) >= softCap;
    }

    function getHardCapReached() public view returns (bool) {
        return token.balanceOf(address(this)) >= hardCap;
    }
}